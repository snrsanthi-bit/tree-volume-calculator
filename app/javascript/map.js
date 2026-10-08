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

  navigator.geolocation.getCurrentPosition((position) => {
    const { latitude, longitude } = position.coords;
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
