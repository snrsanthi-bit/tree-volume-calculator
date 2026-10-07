import L from "leaflet";

document.addEventListener("turbo:load", () => {
  const mapElement = document.getElementById("map");

  if (!mapElement) return;

  if (mapElement._leaflet_id) return;

  const map = L.map(mapElement).setView([35.6762, 139.6503], 13);

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap contributors"
  }).addTo(map);
});
