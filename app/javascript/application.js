import "@hotwired/turbo-rails"
import "calculator"
import "map"

document.addEventListener("turbo:load", () => {
  const menuToggle = document.getElementById("menu-toggle");
  const menu = document.getElementById("menu");

  if (!menuToggle || !menu) return;

  // イベントの二重登録を防ぐ
  if (menuToggle.dataset.initialized === "true") return;
  menuToggle.dataset.initialized = "true";

  menuToggle.addEventListener("click", () => {
  const isExpanded = menuToggle.getAttribute("aria-expanded") === "true";

  menu.classList.toggle("hidden", isExpanded);
  menu.classList.toggle("flex", !isExpanded);
  menuToggle.setAttribute("aria-expanded", String(!isExpanded));
});
});
