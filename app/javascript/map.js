import L from "leaflet";

document.addEventListener("turbo:load", () => {
  const mapElement = document.getElementById("map");

  if (!mapElement) return;
  if (mapElement._leaflet_id) return;

  const japanBounds = L.latLngBounds(
    [24.0, 122.0],
    [46.0, 154.0]
  );

  const map = L.map(mapElement, {
    maxBounds: japanBounds,
    maxBoundsViscosity: 1.0
  }).setView([35.6762, 139.6503], 13);

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap contributors"
  }).addTo(map);

  const workLocationsData = mapElement.dataset.workLocations;

  if (workLocationsData) {
    try {
      const workLocations = JSON.parse(workLocationsData);

      workLocations.forEach((location) => {
        const latlng = [
          Number(location.latitude),
          Number(location.longitude)
        ];

        const marker = L.marker(latlng, {
          title: location.name
        }).addTo(map);

        const popupContent = document.createElement("div");

        const nameElement = document.createElement("div");
        nameElement.textContent = location.name;

        const latitudeElement = document.createElement("div");
        latitudeElement.textContent = `緯度: ${location.latitude}`;

        const longitudeElement = document.createElement("div");
        longitudeElement.textContent = `経度: ${location.longitude}`;

        popupContent.append(nameElement, latitudeElement, longitudeElement);

        marker.bindPopup(popupContent);

      });

    } catch (error) {
      console.error("作業地点を読み込めませんでした", error);
    }
  }

  const outlineVertices = [];
  let outlineLine = null;
  let outlinePolygon = null;
  const vertexMarkers = [];

  const vertexCountElement = document.getElementById(
    "work-area-vertex-count"
  );
  const messageElement = document.getElementById("work-area-message");
  const mapMode = mapElement.dataset.mapMode || "edit";

  function addOutlineVertex(latlng) {
    const vertexIcon = L.divIcon({
      className: "outline-vertex",
      html: "",
      iconSize: [12, 12],
      iconAnchor: [6, 6]
    });

    const marker = L.marker(latlng, {
      icon: vertexIcon
    }).addTo(map);

    vertexMarkers.push(marker);
  }

  function renderOutline() {
    if (outlineLine) {
      map.removeLayer(outlineLine);
    }

    if (outlinePolygon) {
      map.removeLayer(outlinePolygon);
    }

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

    if (vertexCountElement) {
      vertexCountElement.textContent =
        `頂点数：${outlineVertices.length}点`;
    }
  }

// 保存済みの座標があれば復元する
  const savedCoordinates = mapElement.dataset.workAreaCoordinates;

  if (savedCoordinates) {
    try {
      const coordinates = JSON.parse(savedCoordinates);

      coordinates.forEach((coordinate) => {
        const latlng = L.latLng(
          Number(coordinate.lat),
          Number(coordinate.lng)
        );

        outlineVertices.push(latlng);
        addOutlineVertex(latlng);
      });

      if (outlineVertices.length > 0) {
        renderOutline();
        map.fitBounds(L.latLngBounds(outlineVertices), {
          padding: [20, 20]
        });
      }
    } catch (error) {
      console.error("作業範囲の座標を読み込めませんでした", error);
    }
  }

// 詳細画面では編集させない
  if (mapMode !== "show") {
    map.on("click", (event) => {
      outlineVertices.push(event.latlng);
      addOutlineVertex(event.latlng);
      renderOutline();

      if (messageElement) {
        messageElement.textContent = "作業範囲を指定中";
      }
    });
  }
  // 現在地マーカー
  navigator.geolocation.getCurrentPosition((position) => {
    const { latitude, longitude } = position.coords;

    if (!japanBounds.contains([latitude, longitude])) {
      return;
    }

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
  });
});
