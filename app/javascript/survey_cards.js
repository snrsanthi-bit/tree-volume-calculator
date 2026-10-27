// edit / show 画面の「辺の入力カード」。
// 点と線(map.js が survey:changed で渡す)から三角形を導出して表示する。
//   edit : 辺の入力欄は estimated_length（概算）を直す
//   show : 辺の入力欄は measured_length（現場の実測）を入れる。placeholder に概算を出す
// /area ページの手入力カード(calculator.js)には触らない（data-survey-cards がある場合だけ動く）。

import { analyze, computeArea } from "survey_model";

const LABELS = ["A", "B", "C"];

let current = null; // { points, lines }  ※ lines は map.js の state と同じ参照
let lastSignature = "";

const container = () => document.getElementById("triangle-list");
const mode = () => container()?.dataset.surveyCards || null;
const fieldName = () => (mode() === "show" ? "measured_length" : "estimated_length");

function lineOf(id) {
  return current?.lines.find((line) => line.id === id);
}

function inputsOf(lineId) {
  return [...document.querySelectorAll("#triangle-list input[data-line-id]")].filter(
    (input) => input.dataset.lineId === lineId
  );
}

function createCard(triangle, index) {
  const card = document.createElement("div");
  card.className =
    "survey-triangle bg-neutral-dark/40 p-6 rounded-xl border border-neutral-border relative";

  const title = document.createElement("h3");
  title.className = "text-lg font-bold text-primary mb-4";
  title.textContent = `三角形 ${index + 1}`;
  card.append(title);

  const grid = document.createElement("div");
  grid.className = "grid grid-cols-1 sm:grid-cols-3 gap-3 mb-2";

  triangle.lineIds.forEach((lineId, position) => {
    const label = document.createElement("label");
    const caption = document.createElement("span");
    const input = document.createElement("input");

    caption.className = "text-sm text-slate-400 block mb-1";
    caption.textContent = `辺 ${LABELS[position]} (m)`;

    input.className =
      "w-full bg-neutral-dark border border-neutral-border rounded-lg h-12 px-3 text-white text-center";
    input.type = "number";
    input.step = "any";
    input.dataset.lineId = lineId;

    label.append(caption, input);
    grid.append(label);
  });

  const status = document.createElement("p");
  status.className = "survey-triangle-status text-sm text-red-400 min-h-5";

  card.append(grid, status);
  return card;
}

function fillValues() {
  const field = fieldName();

  document.querySelectorAll("#triangle-list input[data-line-id]").forEach((input) => {
    const line = lineOf(input.dataset.lineId);
    if (!line) return;

    if (document.activeElement !== input) {
      input.value = line[field] ?? "";
    }

    input.placeholder = mode() === "show" && line.estimated_length != null ? String(line.estimated_length) : "";
  });
}

function formatArea(total) {
  return `${total.toFixed(2)} ㎡（${(total / 10000).toFixed(4)} ha）`;
}

function updateAreas(triangles) {
  const measured = computeArea(triangles, current.lines, "measured_length");
  const estimated = computeArea(triangles, current.lines, "estimated_length");

  const measuredElement = document.getElementById("survey-area-measured");
  const estimatedElement = document.getElementById("survey-area-estimated");

  if (measuredElement) {
    measuredElement.textContent = measured.complete
      ? `実測面積：${formatArea(measured.total)}`
      : "実測面積：未入力の辺、または三角形にならない辺があります";
  }

  if (estimatedElement) {
    estimatedElement.textContent = estimated.complete
      ? `概算面積：${formatArea(estimated.total)}`
      : "概算面積：計算できません";
  }

  const details = mode() === "show" ? measured.details : estimated.details;

  document.querySelectorAll("#triangle-list .survey-triangle").forEach((card, index) => {
    const status = card.querySelector(".survey-triangle-status");
    if (!status) return;

    status.textContent = details[index]?.status === "invalid" ? "この辺の長さでは三角形を作れません" : "";
  });
}

function render(detail) {
  const list = container();

  if (!list || !mode()) return;

  current = detail;

  const analysis = analyze(detail.points, detail.lines);
  const triangles = analysis.triangles;
  const signature = JSON.stringify(triangles.map((triangle) => triangle.lineIds));

  if (signature !== lastSignature || list.children.length === 0) {
    lastSignature = signature;
    list.replaceChildren();

    if (triangles.length === 0) {
      const note = document.createElement("p");
      note.className = "text-slate-400";
      note.textContent =
        mode() === "show"
          ? "三角形がありません。編集画面で外周と補助線を確認してください"
          : "外周点を3点以上置くと、三角形が表示されます";
      list.append(note);
    }

    triangles.forEach((triangle, index) => list.append(createCard(triangle, index)));
  }

  fillValues();
  updateAreas(triangles);
}

document.addEventListener("survey:changed", (event) => render(event.detail));

document.addEventListener("input", (event) => {
  const input = event.target;

  if (!(input instanceof HTMLInputElement) || !input.dataset.lineId || !current) return;
  if (!input.closest("#triangle-list")) return;

  const lineId = input.dataset.lineId;
  const value = input.value === "" ? null : Number(input.value);

  // 同じ線を共有する別の三角形の入力欄にも反映する
  inputsOf(lineId).forEach((other) => {
    if (other !== input) other.value = input.value;
  });

  document.dispatchEvent(
    new CustomEvent("survey:length-changed", {
      detail: { lineId, field: fieldName(), value: Number.isFinite(value) ? value : null }
    })
  );
});

function highlight(input, on) {
  const line = lineOf(input.dataset.lineId);

  inputsOf(input.dataset.lineId).forEach((other) => {
    other.classList.toggle("ring-2", on);
    other.classList.toggle("ring-primary", on);
  });

  if (!on || !line) {
    document.dispatchEvent(new CustomEvent("edge:highlight", { detail: null }));
    return;
  }

  const from = current.points.find((point) => point.id === line.from);
  const to = current.points.find((point) => point.id === line.to);

  if (!from || !to) return;

  document.dispatchEvent(
    new CustomEvent("edge:highlight", {
      detail: { start: [from.lat, from.lng], end: [to.lat, to.lng] }
    })
  );
}

document.addEventListener("focusin", (event) => {
  const input = event.target;

  if (input instanceof HTMLInputElement && input.dataset.lineId && input.closest("#triangle-list") && current) {
    highlight(input, true);
  }
});

document.addEventListener("focusout", (event) => {
  const input = event.target;

  if (input instanceof HTMLInputElement && input.dataset.lineId && input.closest("#triangle-list") && current) {
    highlight(input, false);
  }
});

// show 画面：実測値の保存
document.addEventListener("click", async (event) => {
  const button = event.target instanceof Element ? event.target.closest("#survey-save-button") : null;

  if (!button || !current) return;

  const url = container()?.dataset.measurementsUrl;
  const message = document.getElementById("survey-save-message");
  const say = (text) => {
    if (message) message.textContent = text;
  };

  if (!url) return;

  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
  const measurements = Object.fromEntries(current.lines.map((line) => [line.id, line.measured_length]));

  button.disabled = true;
  say("保存しています…");

  try {
    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
      },
      body: JSON.stringify({ measurements })
    });

    say(response.ok ? "実測値を保存しました" : "保存に失敗しました。入力値を確認してください");
  } catch (error) {
    console.error("実測値の保存に失敗しました", error);
    say("保存に失敗しました。通信状態を確認してください");
  } finally {
    button.disabled = false;
  }
});
