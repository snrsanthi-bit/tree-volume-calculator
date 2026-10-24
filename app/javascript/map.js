
import L from "leaflet";

function initializeMap() {
  const mapElement = document.getElementById("map");

  if (!mapElement || mapElement._leaflet_id) return;

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
    selectVertex(marker);
  }

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

      deleteSelectedVertex();
    });

    map.on("click", (event) => {
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

document.addEventListener("turbo:load", initializeMap);

