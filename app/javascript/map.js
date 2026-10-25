
import L from "leaflet";

function initializeMap() {
  const mapElement = document.getElementById("map");

  if (!mapElement || mapElement._leaflet_id) {
    return;
  }
  const japanBounds = L.latLngBounds(
    [24.0, 122.0],
    [46.0, 154.0]
  );

  let map;

  try {
    map = L.map(mapElement, {
      maxBounds: japanBounds,
      maxBoundsViscosity: 1.0
    }).setView([35.6762, 139.6503], 13);
    mapElement._leaflet_map = map;
  } catch (error) {
    console.error("地図の初期化に失敗しました", error);
    return;
  }

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap contributors"
  }).addTo(map);

  const outlineVertices = [];
  const vertexMarkers = [];

  const auxiliaryPoints = [];
  const auxiliaryPointMarkers = [];

  let selectedAuxiliaryPoint = null;
  let currentMode = "outline";

  const outlineModeButton = document.getElementById(
    "outline-mode-button"
  );
  const auxiliaryPointModeButton = document.getElementById(
    "auxiliary-point-mode-button"
  );

  const surveyDataInput = document.getElementById(
    "work-area-survey-data"
  );

  let outlineLine = null;
  let outlinePolygon = null;
  let selectedVertex = null;

  const vertexCountElement = document.getElementById(
    "work-area-vertex-count"
  );
  const messageElement = document.getElementById("work-area-message");
  const mapMode = mapElement.dataset.mapMode || "edit";

  const coordinatesInput = document.querySelector(
    'input[name="work_area[coordinates]"]'
  );

  const workAreaForm = coordinatesInput?.closest("form");

  function syncCoordinates() {
    if (!coordinatesInput) return;

    coordinatesInput.value = JSON.stringify(
      outlineVertices.map((vertex) => ({
        lat: vertex.lat,
        lng: vertex.lng
      }))
    );
  }

  let triangulationLayers = [];

  let highlightedEdge = null;

  document.addEventListener("edge:highlight", (event) => {
    if (highlightedEdge) {
      map.removeLayer(highlightedEdge);
      highlightedEdge = null;
    }

    const edge = event.detail;
    if (!edge) return;

    highlightedEdge = L.polyline(
      [edge.start, edge.end],
      {
        color: "#f97316",
        weight: 6,
        opacity: 1,
        interactive: false
      }
    ).addTo(map);
  });

  async function updateTriangulation() {
    triangulationLayers.forEach((layer) => map.removeLayer(layer));
    triangulationLayers = [];

    if (outlineVertices.length < 3) return;

    try {
      const response = await fetch("/area/triangulate", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector(
            'meta[name="csrf-token"]'
          ).content
        },
        body: JSON.stringify({
          points: outlineVertices.map((vertex) => ({
            lat: vertex.lat,
            lng: vertex.lng
          }))
        })
      });

      if (!response.ok) throw new Error("三角分割に失敗しました");

      const { triangles } = await response.json();
      document.dispatchEvent(
        new CustomEvent("triangulation:updated", {
          detail: { triangles }
        })
      );

      triangles.forEach((triangle) => {
        const layer = L.polygon(triangle, {
          color: "#2563eb",
          weight: 2,
          fillOpacity: 0.05
        }).addTo(map);

        triangulationLayers.push(layer);
      });
    } catch (error) {
      console.error("三角分割の更新に失敗しました", error);
    }
  }

  function selectVertex(marker) {
    vertexMarkers.forEach((vertexMarker) => {
      vertexMarker.getElement()?.classList.remove("is-selected");
    });

    marker.getElement()?.classList.add("is-selected");
    selectedVertex = marker;
  }

  function selectAuxiliaryPoint(marker) {
    vertexMarkers.forEach((vertexMarker) => {
      vertexMarker.getElement()?.classList.remove("is-selected");
    });

    auxiliaryPointMarkers.forEach((pointMarker) => {
      pointMarker.getElement()?.classList.remove("is-selected");
    });

    marker.getElement()?.classList.add("is-selected");
    selectedVertex = null;
    selectedAuxiliaryPoint = marker;
  }

  function isInsideOutline(point) {
    if (outlineVertices.length < 3) return false;

    const polygon = L.polygon(outlineVertices);

    return polygon.getBounds().contains(point) &&
      isPointInPolygon(point, outlineVertices);
  }

  function isPointInPolygon(point, vertices) {
    let inside = false;

    for (
      let i = 0, j = vertices.length - 1;
      i < vertices.length;
      j = i++
    ) {
      const a = vertices[i];
      const b = vertices[j];

      const intersects =
        (a.lat > point.lat) !== (b.lat > point.lat) &&
        point.lng <
          ((b.lng - a.lng) * (point.lat - a.lat)) /
            (b.lat - a.lat) +
            a.lng;

      if (intersects) inside = !inside;
    }

    return inside;
  }

    function addAuxiliaryPoint(latlng) {
      if (!isInsideOutline(latlng)) {
        if (messageElement) {
          messageElement.textContent = "外周の内側に配置してください";
        }

        return;
      }
      const icon = L.divIcon({
        className: "auxiliary-point",
        html: '<div class="auxiliary-point-marker"></div>',
        iconSize: [18, 18],
        iconAnchor: [9, 9]
      });

      const marker = L.marker(latlng, {
        icon,
        draggable: true
      }).addTo(map);

      marker.on("click", (event) => {
        L.DomEvent.stopPropagation(event);
        selectAuxiliaryPoint(marker);
      });

      marker.on("dragstart", () => {
        selectAuxiliaryPoint(marker);
      });

      marker.on("dragend", () => {
        const index = auxiliaryPointMarkers.indexOf(marker);

        if (index === -1) return;

        auxiliaryPoints[index] = marker.getLatLng();
        syncAuxiliaryPoints();

      if (messageElement) {
        messageElement.textContent = "補助点の位置を変更しました";
      }
    });

    auxiliaryPoints.push(latlng);
    auxiliaryPointMarkers.push(marker);
    selectAuxiliaryPoint(marker);
    syncAuxiliaryPoints();

    if (messageElement) {
      messageElement.textContent = "補助点を追加しました";
    }
  }

  function syncAuxiliaryPoints() {
    if (!surveyDataInput) return;

    let surveyData = {};

    try {
      surveyData = JSON.parse(surveyDataInput.value || "{}");
    } catch (error) {
      console.error("測量データを読み込めませんでした", error);
    }

    surveyData.auxiliary_points = auxiliaryPoints.map((point, index) => ({
      id: `point-${index + 1}`,
      lat: point.lat,
      lng: point.lng
    }));

    surveyDataInput.value = JSON.stringify(surveyData);
  }

  const triangleListElement = document.getElementById("triangle-list");

  function getSurveyData() {
    try {
      if (surveyDataInput) {
        return JSON.parse(surveyDataInput.value || "{}");
      }

      if (triangleListElement) {
        return JSON.parse(
          triangleListElement.dataset.surveyData || "{}"
        );
      }
    } catch (error) {
      console.error("測量データを読み込めませんでした", error);
    }

    return {};
  }

  function restoreAuxiliaryPoints() {
    const surveyData = getSurveyData();
    const savedPoints = surveyData.auxiliary_points;

    if (!Array.isArray(savedPoints)) return;

    savedPoints.forEach((point) => {
      const lat = Number(point.lat);
      const lng = Number(point.lng);

      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;

      const icon = L.divIcon({
        className: "auxiliary-point",
        html: '<div class="auxiliary-point-marker"></div>',
        iconSize: [18, 18],
        iconAnchor: [9, 9]
      });

      const marker = L.marker([lat, lng], {
        icon,
        draggable: mapMode !== "show"
      }).addTo(map);

      auxiliaryPoints.push(L.latLng(lat, lng));
      auxiliaryPointMarkers.push(marker);
    });
  }

  function deleteSelectedAuxiliaryPoint() {
    if (!selectedAuxiliaryPoint) return;

    const index = auxiliaryPointMarkers.indexOf(selectedAuxiliaryPoint);

    if (index === -1) return;

    map.removeLayer(selectedAuxiliaryPoint);
    auxiliaryPointMarkers.splice(index, 1);
    auxiliaryPoints.splice(index, 1);

    selectedAuxiliaryPoint = null;
    syncAuxiliaryPoints();

    if (messageElement) {
      messageElement.textContent = "補助点を削除しました";
    }
  }

  function renderOutline() {
    if (outlineLine) {
      map.removeLayer(outlineLine);
      outlineLine = null;
    }

    if (outlinePolygon) {
      map.removeLayer(outlinePolygon);
      outlinePolygon = null;
    }

  // 編集画面では外周線を表示する
    if (mapMode !== "show") {
      outlineLine = L.polyline(outlineVertices, {
        color: "#11d442",
        weight: 3,
        className: "work-area-outline"
      }).addTo(map);

      if (outlineVertices.length >= 3) {
        outlinePolygon = L.polygon(outlineVertices, {
          color: "#11d442",
          weight: 3,
          fillColor: "#11d442",
          fillOpacity: 0.2,
          className: "work-area-polygon"
        }).addTo(map);
      }
    }

    if (vertexCountElement) {
      vertexCountElement.textContent =
        `頂点数：${outlineVertices.length}点`;
    }
  }
  function addOutlineVertex(latlng) {
    const vertexIcon = L.divIcon({
      className: "outline-vertex",
      html: "",
      iconSize: [12, 12],
      iconAnchor: [6, 6]
    });

    const marker = L.marker(latlng, {
      icon: vertexIcon,
      draggable: mapMode !== "show"
    }).addTo(map);

    marker.on("click", (event) => {
      L.DomEvent.stopPropagation(event);
      selectVertex(marker);
    });

    marker.on("dragstart", () => {
      selectVertex(marker);
    });

    marker.on("drag", (event) => {
      const index = vertexMarkers.indexOf(marker);

      if (index === -1) return;

      outlineVertices[index] = event.target.getLatLng();
      renderOutline();
      syncCoordinates();
    });



    marker.on("dragend", () => {
      updateTriangulation();
      if (messageElement) {
        messageElement.textContent = "頂点の位置を変更しました";
      }
    });

    vertexMarkers.push(marker);
    if (mapMode !== "show") {
      selectVertex(marker);
    }
  }

  function setMapMode(mode) {
    currentMode = mode;

    outlineModeButton?.setAttribute(
      "aria-pressed",
      String(mode === "outline")
    );

    auxiliaryPointModeButton?.setAttribute(
      "aria-pressed",
      String(mode === "auxiliary")
    );

    if (messageElement) {
      messageElement.textContent = mode === "auxiliary"
        ? "地図をクリックして補助点を追加できます"
        : "地図をクリックして外周点を追加できます";
    }
  }

  outlineModeButton?.addEventListener("click", () => {
    setMapMode("outline");
  });

  auxiliaryPointModeButton?.addEventListener("click", () => {
    setMapMode("auxiliary");
  });

  function deleteSelectedVertex() {
    if (!selectedVertex || mapMode === "show") return;

    const index = vertexMarkers.indexOf(selectedVertex);

    if (index === -1) return;

    map.removeLayer(selectedVertex);
    vertexMarkers.splice(index, 1);
    outlineVertices.splice(index, 1);

    selectedVertex = null;

    renderOutline();
    syncCoordinates();
    updateTriangulation();

    if (messageElement) {
      messageElement.textContent = "頂点を削除しました";
    }
  }

  function restoreCoordinates() {
    const savedCoordinates = mapElement.dataset.workAreaCoordinates;

    if (!savedCoordinates) return;

    try {
      const coordinates = JSON.parse(savedCoordinates);

      if (!Array.isArray(coordinates)) return;

      coordinates.forEach((coordinate) => {
        const lat = Number(coordinate.lat);
        const lng = Number(coordinate.lng);

        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;

        const latlng = L.latLng(lat, lng);

        outlineVertices.push(latlng);
        addOutlineVertex(latlng);
      });

      if (outlineVertices.length > 0) {
        renderOutline();
        syncCoordinates();

        map.fitBounds(L.latLngBounds(outlineVertices), {
          padding: [20, 20]
        });
        if (mapMode !== "show"){
          updateTriangulation();
        }
      }
    } catch (error) {
      console.error("作業範囲の座標を読み込めませんでした", error);
    }
  }

  // 詳細画面では頂点の削除・追加・移動を禁止する
  if (mapMode !== "show") {
    document.addEventListener("keydown", (event) => {
      if (event.key.toLowerCase() !== "d") return;

      const activeElement = document.activeElement;

      if (
        activeElement instanceof HTMLInputElement ||
        activeElement instanceof HTMLTextAreaElement ||
        activeElement?.isContentEditable
      ) {
        return;
      }

      if (selectedAuxiliaryPoint) {
        deleteSelectedAuxiliaryPoint();
        return;
      }

      deleteSelectedVertex();
    });

    map.on("click", (event) => {
      if (currentMode === "auxiliary") {
        addAuxiliaryPoint(event.latlng);
        return;
      }

      selectedAuxiliaryPoint = null;

      outlineVertices.push(event.latlng);
      addOutlineVertex(event.latlng);
      renderOutline();
      syncCoordinates();
      updateTriangulation();

      if (messageElement) {
        messageElement.textContent = "作業範囲を指定中";
      }
    });
  }

  restoreCoordinates();
  restoreAuxiliaryPoints();

  // DOMの描画後に地図サイズを再計算する
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      map.invalidateSize();
    });
  });

  // 現在地が取得できた場合はマーカーを表示する
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;

        if (!japanBounds.contains([latitude, longitude])) return;

        const currentLocationIcon = L.divIcon({
          className: "current-location-marker",
          html: '<div class="marker-pin"></div>',
          iconSize: [30, 30],
          iconAnchor: [15, 15]
        });

        map.setView([latitude, longitude], 16);

        L.marker([latitude, longitude], {
          icon: currentLocationIcon
        }).addTo(map);
      }
    );
  }

  if (workAreaForm) {
    workAreaForm.addEventListener("submit", syncCoordinates);
  }
}

document.addEventListener("turbo:load", () => {
  initializeMap();
});

