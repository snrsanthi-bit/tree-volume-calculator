document.addEventListener("turbo:load", function() {
  console.log("calculator.js turbo:load 初期化");
  const triangleList = document.getElementById("triangle-list");
  const addTriangleButton = document.getElementById("add-triangle-button");
  const calculateAreaButton = document.getElementById("calculate-area-button");
  const surveyDataInput = document.getElementById("work-area-survey-data");
  let surveyTriangles = [];

  document.addEventListener("triangulation:updated", function(event) {
    try {

      // new・editでは三角形を生成して保存データを作る。
      // showでは保存済みデータを使うので、再生成しない。
      if (!surveyDataInput) return;
      const { triangles } = event.detail;

      if (!Array.isArray(triangles)) {
        throw new Error("triangles が配列ではありません");
      }

      if (!triangleList) {
        throw new Error("#triangle-list が見つかりません");
      }

      console.log("三角形の受信数:", triangles.length);

      if (!triangleList) {
        console.log("triangle-list が見つかりません");
        return;
      }

      triangleList.innerHTML = "";
      triangleCount = triangles.length;

      surveyTriangles = triangles.map((triangle, index) => {
        const [point1, point2, point3] = triangle;

        const edges = [
          { name: "a", start: point1, end: point2 },
          { name: "b", start: point2, end: point3 },
          { name: "c", start: point3, end: point1 }
        ];

        triangleList.insertAdjacentHTML(
          "beforeend",
          createTriangleHTML(index + 1)
        );

        const card = triangleList.lastElementChild;

        const savedEdges = edges.map(edge => {
          const input = card.querySelector(`.${edge.name}`);
          const estimatedLength = distanceMeters(edge.start, edge.end);

          input.value = estimatedLength.toFixed(1);
          input.dataset.edgeStart = JSON.stringify(edge.start);
          input.dataset.edgeEnd = JSON.stringify(edge.end);

          return {
            name: edge.name,
            start: edge.start,
            end: edge.end,
            estimated_length: Number(estimatedLength.toFixed(1)),
            measured_length: null
          };
        });

        return {
          number: index + 1,
          vertices: triangle,
          edges: savedEdges
        };
      });

      if (surveyDataInput) {
        surveyDataInput.value = JSON.stringify({
          triangles: surveyTriangles
        });
      }

      const sharedEdges = findSharedEdges();

      console.log("共通辺の数:", sharedEdges.length);

      syncSharedEdges(sharedEdges);

      document.querySelectorAll(
        "#triangle-list .a, #triangle-list .b, #triangle-list .c"
      ).forEach(input => {
        input.addEventListener("input", updateSurveyData);
      });
    } catch (error) {
      console.error("三角形リストの生成に失敗しました:", error);
    }
  }); // triangulation:updated のリスナーを閉じる

  let triangleCount = 1;

    if (triangleList && !surveyDataInput) {
      const savedData = triangleList.dataset.surveyData;

      if (savedData) {
        try {
          const parsedData = JSON.parse(savedData);
          surveyTriangles = parsedData.triangles || [];

          surveyTriangles.forEach((triangle, index) => {
            triangleList.insertAdjacentHTML(
              "beforeend",
              createTriangleHTML(index + 1)
            );

          const card = triangleList.lastElementChild;

          triangle.edges.forEach(edge => {
            const input = card.querySelector(`.${edge.name}`);

            if (!input) return;

            input.value = edge.estimated_length ?? "";
            input.dataset.edgeStart = JSON.stringify(edge.start);
            input.dataset.edgeEnd = JSON.stringify(edge.end);
          });
        });

        const sharedEdges = findSharedEdges();
        syncSharedEdges(sharedEdges);
      } catch (error) {
        console.error("三角形データの復元に失敗:", error);
      }
    }
  }

  const menuButton = document.querySelector('button[aria-label="メニュー"]');
  const menu = document.getElementById("menu");

   if (menuButton && menu) {
    menuButton.addEventListener("click", function() {
    menu.classList.toggle("hidden");
    });
  }

  function triangleArea(a, b, c) {
    const s = (a + b + c) / 2;
    return Math.sqrt(s * (s - a) * (s - b) * (s - c));
  }

  function distanceMeters(point1, point2) {
    const toRad = (degrees) => degrees * Math.PI / 180;
    const earthRadius = 6371000;

    const lat1 = point1[0];
    const lng1 = point1[1];
    const lat2 = point2[0];
    const lng2 = point2[1];

    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);

    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLng / 2) ** 2;

    return 2 * earthRadius *
      Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  function edgeKey(point1, point2) {
    const normalize = point =>
      point.map(coordinate => coordinate.toFixed(6));

    const startKey = normalize(point1).join(",");
    const endKey = normalize(point2).join(",");

    return startKey < endKey
      ? `${startKey}|${endKey}`
      : `${endKey}|${startKey}`;
  }

  function findSharedEdges() {
    const edges = new Map();

    document.querySelectorAll("#triangle-list .triangle").forEach(card => {
      ["a", "b", "c"].forEach(name => {
        const input = card.querySelector(`.${name}`);
        const startData = input.dataset.edgeStart;
        const endData = input.dataset.edgeEnd;

        if (!startData || !endData) return;

        const start = JSON.parse(startData);
        const end = JSON.parse(endData);
        const key = edgeKey(start, end);

        if (!edges.has(key)) {
          edges.set(key, []);
        }

        edges.get(key).push(input);
      });
    });

    return [...edges.values()].filter(inputs => inputs.length > 1);
  }

  function syncSharedEdges(sharedEdges) {
    const sharedInputGroups = new Map();

    sharedEdges.forEach(inputs => {
      inputs.forEach(input => {
        sharedInputGroups.set(input, inputs);
      });
    });

    document.querySelectorAll("#triangle-list .a, #triangle-list .b, #triangle-list .c")
      .forEach(input => {
        input.addEventListener("focus", function() {
          const group = sharedInputGroups.get(input) || [input];

          group.forEach(otherInput => {
            otherInput.classList.add("ring-2", "ring-primary");
          });

          document.dispatchEvent(
            new CustomEvent("edge:highlight", {
              detail: {
                start: JSON.parse(input.dataset.edgeStart),
                end: JSON.parse(input.dataset.edgeEnd)
              }
            })
          );
        });

        input.addEventListener("blur", function() {
          const group = sharedInputGroups.get(input) || [input];

          group.forEach(otherInput => {
            otherInput.classList.remove("ring-2", "ring-primary");
          });

          document.dispatchEvent(
            new CustomEvent("edge:highlight", {
              detail: null
            })
          );
        });
      });

    sharedEdges.forEach(inputs => {
      inputs.forEach(input => {
        input.addEventListener("input", function() {
          inputs.forEach(otherInput => {
            if (otherInput !== input) {
              otherInput.value = input.value;
            }
          });
        });
      });
    });
  }



  function updateSurveyData() {
    if (!surveyDataInput) return;

    document.querySelectorAll("#triangle-list .triangle").forEach(
      (card, index) => {
        ["a", "b", "c"].forEach(name => {
          const input = card.querySelector(`.${name}`);
          const edge = surveyTriangles[index]?.edges.find(
            item => item.name === name
          );

          if (edge) {
            edge.estimated_length = input.value === ""
              ? null
              : Number(input.value);
          }
        })
      }
    );

    surveyDataInput.value = JSON.stringify({
      triangles: surveyTriangles
    });
  }

  const workAreaForm = surveyDataInput?.closest("form");

    if (workAreaForm) {
      workAreaForm.addEventListener("submit", updateSurveyData);
    }

  function createTriangleHTML(count) {
    return `
      <div class="triangle bg-neutral-dark/40 p-6 rounded-xl border border-neutral-border relative">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-bold text-primary">三角形 ${count}</h3>
          <button onclick="this.closest('.triangle').remove()" class="text-slate-400 hover:text-red-400 transition-colors">
            <span class="material-symbols-outlined">delete</span>
          </button>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-4">
          <label>
            <span class="text-sm text-slate-400 block mb-1">辺 A (m)</span>
            <input class="a w-full bg-neutral-dark border border-neutral-border rounded-lg h-12 px-3 text-white text-center" type="number" step="any">
          </label>
          <label>
            <span class="text-sm text-slate-400 block mb-1">辺 B (m)</span>
            <input class="b w-full bg-neutral-dark border border-neutral-border rounded-lg h-12 px-3 text-white text-center" type="number" step="any">
          </label>
          <label>
            <span class="text-sm text-slate-400 block mb-1">辺 C (m)</span>
            <input class="c w-full bg-neutral-dark border border-neutral-border rounded-lg h-12 px-3 text-white text-center" type="number" step="any">
          </label>
        </div>
      </div>
    `;
  }

  if (addTriangleButton) {
    addTriangleButton.addEventListener("click", function(event) {
      event.preventDefault();
      triangleCount++;
      triangleList.insertAdjacentHTML("beforeend", createTriangleHTML(triangleCount));
    });
  }

  if (calculateAreaButton) {
    calculateAreaButton.addEventListener("click", function(event) {
      event.preventDefault();
      let total = 0;
      let error = null;

      document.querySelectorAll("#triangle-list .triangle").forEach(tri => {
        const a = parseFloat(tri.querySelector(".a").value);
        const b = parseFloat(tri.querySelector(".b").value);
        const c = parseFloat(tri.querySelector(".c").value);

        if (Number.isNaN(a) || a <= 0){
          error = "side_a";
          return;
        }

        if (Number.isNaN(b) || b <= 0){
          error = "side_b";
          return;
        }

        if (Number.isNaN(c) || c <= 0){
          error = "side_c"
          return;
        }

        if (a + b <= c || a + c <= b || b + c <= a) {
          error = "triangle_invalid";
          return;
        }

        total += triangleArea(a, b, c);
      });

      if (error){
        fetch(`/area/calculate?error=${error}`, {
          headers:{
            Accept: "text/vnd.turbo-stream.html"
          }
        })
        .then(response => response.text())
        .then(html => Turbo.renderStreamMessage(html));
        return;
      }

      // Send the data to the server using Turbo Stream
      fetch(`/area/calculate?area=${total}`, {
        headers: {
          Accept: "text/vnd.turbo-stream.html"
        }
      })    
      .then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html));
    });

  };
});
