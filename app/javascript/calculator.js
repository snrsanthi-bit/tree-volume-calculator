document.addEventListener("turbo:load", function() {
  const triangleList = document.getElementById("triangle-list");
  const addTriangleButton = document.getElementById("add-triangle-button");
  const calculateAreaButton = document.getElementById("calculate-area-button");
  let triangleCount = 1;

  function triangleArea(a, b, c) {
    const s = (a + b + c) / 2;
    return Math.sqrt(s * (s - a) * (s - b) * (s - c));
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
        <div class="grid grid-cols-3 gap-3 mb-4">
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
        fetch(`/area?error=${error}`, {
          headers:{
            Accept: "text/vnd.turbo-stream.html"
          }
        })
        .then(response => response.text())
        .then(html => Turbo.renderStreamMessage(html));
        return;
      }

      // Send the data to the server using Turbo Stream
      fetch(`/area?area=${total}`, {
        headers: {
          Accept: "text/vnd.turbo-stream.html"
        }
      })    
      .then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html));
    });
  }
});
