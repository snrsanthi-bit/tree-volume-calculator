import L from "leaflet";
import {
  analyze,
  buildFromTriangles,
  carryOverMeasurements,
  distanceMeters,
  hasMeasured,
  nextNumericId,
  pairKey,
  pointInPolygon,
  round1,
  snapshotProposed
} from "survey_model";

// Turbo で画面遷移しても document のリスナーが増えないよう、ここで1回だけ登録する。
// 現在表示中の地図は initializeMap() が `active` に差し込む。
let active = null;

document.addEventListener("edge:highlight", (event) => active?.highlightEdge(event.detail));

document.addEventListener("survey:length-changed", (event) => active?.setLineLength(event.detail));

document.addEventListener("keydown", (event) => {
  if (event.key.toLowerCase() !== "d") return;

  const target = document.activeElement;

  if (
    target instanceof HTMLInputElement ||
    target instanceof HTMLTextAreaElement ||
    target?.isContentEditable
  ) {
    return;
  }

  active?.deleteSelected();
});

function initializeMap() {
  const mapElement = document.getElementById("map");

  if (!mapElement || mapElement._leaflet_id) return;

  const japanBounds = L.latLngBounds([24.0, 122.0], [46.0, 154.0]);
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

  const mapMode = mapElement.dataset.mapMode || "edit";
  const isShow = mapMode === "show";

  const outlineModeButton = document.getElementById("outline-mode-button");
  const auxiliaryPointModeButton = document.getElementById("auxiliary-point-mode-button");
  const auxiliaryLineModeButton = document.getElementById("auxiliary-line-mode-button");
  const surveyDataInput = document.getElementById("work-area-survey-data");
  const vertexCountElement = document.getElementById("work-area-vertex-count");
  const messageElement = document.getElementById("work-area-message");
  const triangleListElement = document.getElementById("triangle-list");
  const coordinatesInput = document.querySelector('input[name="work_area[coordinates]"]');
  const workAreaForm = coordinatesInput?.closest("form");

  // ---- 状態 -------------------------------------------------------------
  // 保存するのは points / lines / proposed / lines_edited だけ。面は analyze() で導出する。
  const state = {
    points: [],
    lines: [],
    proposed: null, // new の提案（一度保存したら上書きしない）
    proposedFrozen: false,
    linesEdited: false // 作業者が線を足した/消した後は、外周を動かしても自動で再提案しない
  };

  const markers = new Map(); // pointId -> L.marker
  const lineLayers = new Map(); // lineId -> L.polyline

  let currentMode = "outline";
  let selected = null; // { type: "point" | "line", id }
  let lineStartId = null;
  let dragSnapshot = null; // ドラッグ開始時の状態（実測値が消える移動をキャンセルしたときに戻す）
  let problemLayers = [];
  let highlightedEdge = null;
  let proposeSequence = 0;
  let proposing = false;
  let outlineLine = null;
  let outlinePolygon = null;

  const setMessage = (text) => {
    if (messageElement) messageElement.textContent = text;
  };

  const pointById = (id) => state.points.find((p) => p.id === id);
  const lineById = (id) => state.lines.find((l) => l.id === id);

  // ---- 読み込み ---------------------------------------------------------
  function getSurveyData() {
    try {
      if (surveyDataInput) return JSON.parse(surveyDataInput.value || "{}");
      if (triangleListElement) return JSON.parse(triangleListElement.dataset.surveyData || "{}");
    } catch (error) {
      console.error("測量データを読み込めませんでした", error);
    }

    return {};
  }

  const finite = (value) => (Number.isFinite(Number(value)) && value !== null ? Number(value) : null);

  function loadState() {
    const data = getSurveyData();

    if (Array.isArray(data.points) && data.points.length > 0) {
      state.points = data.points
        .filter((p) => p && finite(p.lat) !== null && finite(p.lng) !== null && p.id)
        .map((p) => ({
          id: String(p.id),
          lat: Number(p.lat),
          lng: Number(p.lng),
          origin: p.origin === "worker" ? "worker" : "input"
        }));

      const ids = new Set(state.points.map((p) => p.id));

      state.lines = (Array.isArray(data.lines) ? data.lines : [])
        .filter((l) => l && ids.has(l.from) && ids.has(l.to))
        .map((l) => ({
          id: String(l.id),
          from: l.from,
          to: l.to,
          origin: l.origin === "worker" ? "worker" : "proposed",
          estimated_length: finite(l.estimated_length),
          measured_length: finite(l.measured_length)
        }));
    } else {
      // 保存済みの測量データが無い場合は、外周の座標から始める（線は提案APIが作る）
      try {
        const coordinates = JSON.parse(mapElement.dataset.workAreaCoordinates || "[]");

        state.points = (Array.isArray(coordinates) ? coordinates : [])
          .filter((c) => finite(c.lat) !== null && finite(c.lng) !== null)
          .map((c, index) => ({
            id: `p-${index + 1}`,
            lat: Number(c.lat),
            lng: Number(c.lng),
            origin: "input"
          }));
      } catch (error) {
        console.error("作業範囲の座標を読み込めませんでした", error);
      }
    }

    state.proposed = data.proposed || null;
    state.proposedFrozen = Boolean(data.proposed);
    state.linesEdited = Boolean(data.lines_edited);
  }

  // ---- 保存用データへの書き出し -----------------------------------------
  function serialize() {
    return {
      version: 2,
      points: state.points,
      lines: state.lines,
      proposed: state.proposed,
      lines_edited: state.linesEdited
    };
  }

  // 外周の表示（緑）。線から外周を導出できればそれを、できなければ外周点を結ぶ。
  // /area ページの spec(.work-area-outline / .work-area-polygon)がこの表示を前提にしている。
  function renderOutline() {
    if (outlineLine) map.removeLayer(outlineLine);
    if (outlinePolygon) map.removeLayer(outlinePolygon);

    outlineLine = null;
    outlinePolygon = null;

    if (isShow) return;

    const analysis = analyze(state.points, state.lines);
    const ring = (analysis.outline
      ? analysis.outline.map(pointById)
      : state.points.filter((p) => p.origin === "input")
    ).map((p) => [p.lat, p.lng]);

    if (ring.length < 2) return;

    const style = { color: "#11d442", weight: 3, interactive: false };

    outlineLine = L.polyline(ring, { ...style, className: "work-area-outline" }).addTo(map);

    if (ring.length >= 3) {
      outlinePolygon = L.polygon(ring, {
        ...style,
        fillColor: "#11d442",
        fillOpacity: 0.2,
        className: "work-area-polygon"
      }).addTo(map);
    }
  }

  function sync() {
    clearProblemHighlight();
    renderOutline();

    const inputCount = state.points.filter((p) => p.origin === "input").length;

    if (vertexCountElement) vertexCountElement.textContent = `頂点数：${inputCount}点`;
    if (surveyDataInput) surveyDataInput.value = JSON.stringify(serialize());

    document.dispatchEvent(
      new CustomEvent("survey:changed", {
        detail: { points: state.points, lines: state.lines }
      })
    );
  }

  // ---- 点 ---------------------------------------------------------------
  function createMarker(point) {
    const isAuxiliary = point.origin === "worker";

    const icon = isAuxiliary
      ? L.divIcon({
          className: "auxiliary-point",
          html: '<div class="auxiliary-point-marker"></div>',
          iconSize: [18, 18],
          iconAnchor: [9, 9]
        })
      : L.divIcon({
          className: "outline-vertex",
          html: "",
          iconSize: [12, 12],
          iconAnchor: [6, 6]
        });

    const marker = L.marker([point.lat, point.lng], { icon, draggable: !isShow }).addTo(map);

    marker.on("click", (event) => {
      L.DomEvent.stopPropagation(event);

      if (currentMode === "auxiliary-line") {
        handleLinePointClick(point.id);
        return;
      }

      selectItem({ type: "point", id: point.id });
    });

    marker.on("dragstart", () => {
      dragSnapshot = takeSnapshot();
      selectItem({ type: "point", id: point.id });
    });

    marker.on("drag", () => {
      const latlng = marker.getLatLng();
      const target = pointById(point.id);

      target.lat = latlng.lat;
      target.lng = latlng.lng;
      redrawLinesOf(point.id);
    });

    marker.on("dragend", () => {
      const snapshot = dragSnapshot ?? takeSnapshot();
      dragSnapshot = null;

      // 位置が変わっていなければ何もしない（実測値の確認も出さない）
      const before = snapshot.points.find((p) => p.id === point.id);
      const current = pointById(point.id);

      if (before && current && before.lat === current.lat && before.lng === current.lng) return;

      // 点が動くと、つながる線は形が変わる。実測済みの線があれば、動かす前に確認する
      const connected = state.lines.filter((l) => (l.from === point.id || l.to === point.id) && hasMeasured(l));

      if (!confirmMeasuredLoss(connected.length)) {
        setTimeout(() => restoreSnapshot(snapshot), 0);
        return;
      }

      connected.forEach((l) => {
        l.measured_length = null;
      });

      refreshEstimates(point.id);
      setMessage(isAuxiliary ? "補助点の位置を変更しました" : "頂点の位置を変更しました");

      if (!isAuxiliary && !state.linesEdited) {
        sync();
        propose(snapshot, connected.length > 0);
      } else {
        sync();
      }
    });

    markers.set(point.id, marker);
  }

  function addPoint(latlng, origin) {
    const point = {
      id: `p-${nextNumericId("p-", state.points)}`,
      lat: latlng.lat,
      lng: latlng.lng,
      origin
    };

    state.points.push(point);
    createMarker(point);

    return point;
  }

  function removePoint(id) {
    state.lines.filter((l) => l.from === id || l.to === id).forEach((l) => removeLine(l.id));

    const marker = markers.get(id);
    if (marker) map.removeLayer(marker);

    markers.delete(id);
    state.points = state.points.filter((p) => p.id !== id);
  }

  function isInsideOutline(latlng) {
    const analysis = analyze(state.points, state.lines);

    if (!analysis.outline) return false;

    return pointInPolygon(latlng, analysis.outline.map(pointById));
  }

  function addAuxiliaryPoint(latlng) {
    if (!isInsideOutline(latlng)) {
      setMessage("外周の内側に配置してください");
      return;
    }

    const point = addPoint(latlng, "worker");

    selectItem({ type: "point", id: point.id });
    sync();
    setMessage("補助点を追加しました");
  }

  // ---- 線 ---------------------------------------------------------------
  function drawLine(line) {
    const from = pointById(line.from);
    const to = pointById(line.to);
    const isWorker = line.origin === "worker";

    const layer = L.polyline(
      [[from.lat, from.lng], [to.lat, to.lng]],
      {
        color: isWorker ? "#f97316" : "#2563eb",
        weight: 3,
        className: isWorker ? "survey-line auxiliary-line" : "survey-line proposed-line",
        interactive: !isShow
      }
    ).addTo(map);

    if (!isShow) {
      layer.on("click", (event) => {
        L.DomEvent.stopPropagation(event);

        if (currentMode === "auxiliary-line") return;

        selectItem({ type: "line", id: line.id });
      });
    }

    lineLayers.set(line.id, layer);
  }

  function removeLine(id) {
    const layer = lineLayers.get(id);
    if (layer) map.removeLayer(layer);

    lineLayers.delete(id);
    state.lines = state.lines.filter((l) => l.id !== id);
  }

  function redrawLinesOf(pointId) {
    state.lines
      .filter((l) => l.from === pointId || l.to === pointId)
      .forEach((line) => {
        const from = pointById(line.from);
        const to = pointById(line.to);

        lineLayers.get(line.id)?.setLatLngs([[from.lat, from.lng], [to.lat, to.lng]]);
      });
  }

  // 点を動かしたら、その点につながる線の概算（estimated_length）を地図から計算し直す
  function refreshEstimates(pointId) {
    state.lines
      .filter((l) => l.from === pointId || l.to === pointId)
      .forEach((line) => {
        line.estimated_length = round1(distanceMeters(pointById(line.from), pointById(line.to)));
      });
  }

  function handleLinePointClick(id) {
    if (!lineStartId) {
      lineStartId = id;
      setMessage("補助線の終点を選択してください");
      return;
    }

    if (lineStartId === id) return;

    const from = lineStartId;
    lineStartId = null;

    if (state.lines.some((l) => pairKey(l.from, l.to) === pairKey(from, id))) {
      setMessage("同じ線がすでにあります");
      return;
    }

    const line = {
      id: `l-${nextNumericId("l-", state.lines)}`,
      from,
      to: id,
      origin: "worker",
      estimated_length: round1(distanceMeters(pointById(from), pointById(id))),
      measured_length: null
    };

    state.lines.push(line);
    state.linesEdited = true;
    drawLine(line);
    sync();
    setMessage("補助線を作成しました");
  }

  // ---- 実測値の保護 -----------------------------------------------------
  // 実測値が消える操作は、実行前に確認する。キャンセルしたら操作前の状態へ戻す。
  function confirmMeasuredLoss(count, additional = false) {
    if (count === 0) return true;

    const prefix = additional ? "他にも、" : "";

    return window.confirm(
      `${prefix}実測値が入力済みの線が${count}本あります。この操作で形が変わる線の実測値は消え、再測定が必要になります。続けますか？`
    );
  }

  function takeSnapshot() {
    return JSON.parse(
      JSON.stringify({ points: state.points, lines: state.lines, linesEdited: state.linesEdited })
    );
  }

  function restoreSnapshot(snapshot) {
    selectItem(null);

    markers.forEach((marker) => map.removeLayer(marker));
    markers.clear();
    lineLayers.forEach((layer) => map.removeLayer(layer));
    lineLayers.clear();

    state.points = snapshot.points;
    state.lines = snapshot.lines;
    state.linesEdited = snapshot.linesEdited;

    state.points.forEach(createMarker);
    state.lines.forEach(drawLine);
    sync();
    setMessage("操作を取り消しました");
  }

  function replaceProposedLines(newLines) {
    state.lines.filter((l) => l.origin === "proposed").forEach((l) => removeLine(l.id));

    newLines.forEach((line) => {
      state.lines.push(line);
      drawLine(line);
    });
  }

  // ---- 選択 -------------------------------------------------------------
  function selectItem(item) {
    markers.forEach((marker) => marker.getElement()?.classList.remove("is-selected"));
    lineLayers.forEach((layer, id) => layer.setStyle(lineStyle(lineById(id), false)));

    selected = item;

    if (!item) return;

    if (item.type === "point") {
      markers.get(item.id)?.getElement()?.classList.add("is-selected");
    } else {
      lineLayers.get(item.id)?.setStyle(lineStyle(lineById(item.id), true));
    }
  }

  function lineStyle(line, isSelected) {
    if (isSelected) return { color: "#ef4444", weight: 6 };

    return { color: line?.origin === "worker" ? "#f97316" : "#2563eb", weight: 3 };
  }

  function deleteSelected() {
    if (isShow || !selected) return;

    const item = selected;
    const snapshot = takeSnapshot();

    // 削除でつながる線ごと実測値が消える場合は、削除前に確認する
    const affected =
      item.type === "line"
        ? state.lines.filter((l) => l.id === item.id && hasMeasured(l))
        : state.lines.filter((l) => (l.from === item.id || l.to === item.id) && hasMeasured(l));

    if (!confirmMeasuredLoss(affected.length)) return;

    selected = null;

    if (item.type === "line") {
      removeLine(item.id);
      state.linesEdited = true;
      sync();
      setMessage("線を削除しました");
      return;
    }

    const point = pointById(item.id);
    if (!point) return;

    removePoint(item.id);
    sync();

    if (point.origin === "worker") {
      setMessage("補助点を削除しました");
      return;
    }

    setMessage("頂点を削除しました");
    if (!state.linesEdited) propose(snapshot, affected.length > 0);
  }

  // ---- ロジックによる三角分割の提案（new） ------------------------------
  // 提案の線を作り直す。座標が同じ線の実測値は引き継ぐ。
  // 引き継げない実測値がある場合は、適用前に確認し、キャンセルなら snapshot の状態へ戻す。
  async function propose(snapshot = null, additional = false) {
    const sequence = ++proposeSequence;
    const dataset = mapElement.dataset;
    const inputs = state.points.filter((p) => p.origin === "input");

    // 戻り値 true = 適用した / false = 利用者がキャンセルして元に戻した
    const applyProposal = (builtLines) => {
      const oldProposed = state.lines.filter((l) => l.origin === "proposed");
      const { lines, lostCount } = carryOverMeasurements(oldProposed, state.points, builtLines, state.points);

      // 削除・移動の時点で確認済みの分は state から外れているので、ここで数えるのは「他に」消える分
      if (snapshot && !confirmMeasuredLoss(lostCount, additional)) {
        restoreSnapshot(snapshot);
        return false;
      }

      replaceProposedLines(lines);
      return true;
    };

    proposing = true;
    dataset.triangulationReady = "false";
    dataset.triangulationStage = "start";
    dataset.triangulationError = "";

    try {
      if (inputs.length < 3) {
        if (!applyProposal([])) {
          dataset.triangulationStage = "cancelled";
          dataset.triangulationReady = "true";
          return;
        }
      } else {
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

        const response = await fetch("/area/triangulate", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
          },
          body: JSON.stringify({ points: inputs.map(({ lat, lng }) => ({ lat, lng })) })
        });

        dataset.triangulationStage = `response-${response.status}`;

        if (!response.ok) {
          const body = await response.json().catch(() => ({}));
          throw new Error(body.error || `三角分割に失敗しました: HTTP ${response.status}`);
        }

        const { triangles } = await response.json();

        if (sequence !== proposeSequence) return; // より新しい提案が走っている

        const built = buildFromTriangles(inputs, triangles, nextNumericId("l-", state.lines));

        if (!applyProposal(built)) {
          dataset.triangulationStage = "cancelled";
          dataset.triangulationReady = "true";
          return;
        }

        dataset.triangulationStage = "json";
      }

      if (!state.proposedFrozen) state.proposed = snapshotProposed(state.points, state.lines);

      dataset.triangulationReady = "true";
    } catch (error) {
      if (sequence !== proposeSequence) return;

      // 失敗しても既存の線・実測値は消さない。作り直しは行わず、メッセージで知らせる。
      // （点と線がずれた状態は、保存時の検証で止まる）
      dataset.triangulationStage = "error";
      dataset.triangulationError = String(error);
      setMessage(`${error.message}（既存の線・実測値は変更していません。もう一度操作してください）`);
      console.error("三角分割の更新に失敗しました", error);
    } finally {
      if (sequence === proposeSequence) {
        proposing = false;
        sync();
      }
    }
  }

  // ---- 保存時の検証 -----------------------------------------------------
  function clearProblemHighlight() {
    problemLayers.forEach((layer) => map.removeLayer(layer));
    problemLayers = [];
    markers.forEach((marker) => marker.getElement()?.classList.remove("is-error"));
  }

  function highlightProblems(errors) {
    clearProblemHighlight();

    const lineIds = new Set(errors.flatMap((e) => e.lineIds));
    const pointIds = new Set(errors.flatMap((e) => e.pointIds));

    lineIds.forEach((id) => {
      const line = lineById(id);
      if (!line) return;

      const from = pointById(line.from);
      const to = pointById(line.to);

      problemLayers.push(
        L.polyline([[from.lat, from.lng], [to.lat, to.lng]], {
          color: "#dc2626",
          weight: 7,
          opacity: 0.9,
          interactive: false,
          className: "auxiliary-line-error"
        }).addTo(map)
      );
    });

    pointIds.forEach((id) => markers.get(id)?.getElement()?.classList.add("is-error"));
  }

  if (workAreaForm && !isShow) {
    workAreaForm.addEventListener("submit", (event) => {
      clearProblemHighlight();

      if (proposing) {
        event.preventDefault();
        setMessage("三角分割を計算中です。少し待ってからもう一度保存してください");
        return;
      }

      const analysis = analyze(state.points, state.lines);

      if (!analysis.ok) {
        event.preventDefault();

        // 最初に直すべき種類のエラーだけを強調する
        const first = analysis.errors[0];
        highlightProblems(analysis.errors.filter((e) => e.type === first.type));
        setMessage(first.message);
        mapElement.scrollIntoView({ behavior: "smooth", block: "center" });
        return;
      }

      // coordinates 列は、線から導出した外周（反時計回り）の写しとして保存する
      if (coordinatesInput) {
        coordinatesInput.value = JSON.stringify(
          analysis.outline.map((id) => {
            const point = pointById(id);
            return { lat: point.lat, lng: point.lng };
          })
        );
      }
    });
  }

  // ---- モード切替 -------------------------------------------------------
  function setMapMode(mode) {
    currentMode = mode;
    lineStartId = null;

    outlineModeButton?.setAttribute("aria-pressed", String(mode === "outline"));
    auxiliaryPointModeButton?.setAttribute("aria-pressed", String(mode === "auxiliary"));
    auxiliaryLineModeButton?.setAttribute("aria-pressed", String(mode === "auxiliary-line"));

    setMessage(
      {
        outline: "地図をクリックして外周点を追加できます",
        auxiliary: "地図をクリックして補助点を追加できます",
        "auxiliary-line": "補助線モード：始点と終点を選択してください"
      }[mode]
    );
  }

  outlineModeButton?.addEventListener("click", () => setMapMode("outline"));
  auxiliaryPointModeButton?.addEventListener("click", () => setMapMode("auxiliary"));
  auxiliaryLineModeButton?.addEventListener("click", () => setMapMode("auxiliary-line"));

  if (!isShow) {
    map.on("click", (event) => {
      if (currentMode === "auxiliary-line") return;

      if (currentMode === "auxiliary") {
        addAuxiliaryPoint(event.latlng);
        return;
      }

      const snapshot = takeSnapshot();
      const point = addPoint(event.latlng, "input");

      selectItem({ type: "point", id: point.id });
      sync();
      setMessage("作業範囲を指定中");

      if (!state.linesEdited) propose(snapshot);
    });
  }

  // ---- 初期化 -----------------------------------------------------------
  loadState();
  state.points.forEach(createMarker);
  state.lines.forEach(drawLine);

  if (state.points.length > 0) {
    map.fitBounds(L.latLngBounds(state.points.map((p) => [p.lat, p.lng])), { padding: [20, 20] });
  }

  const hasInputPoints = state.points.filter((p) => p.origin === "input").length >= 3;

  if (!isShow && state.lines.length === 0 && hasInputPoints) {
    propose();
  } else {
    mapElement.dataset.triangulationReady = "true";
    mapElement.dataset.triangulationStage = "restored";
  }

  sync();

  active = {
    deleteSelected,
    highlightEdge(edge) {
      if (highlightedEdge) map.removeLayer(highlightedEdge);
      highlightedEdge = null;

      if (!edge) return;

      highlightedEdge = L.polyline([edge.start, edge.end], {
        color: "#eab308",
        weight: 9,
        opacity: 1,
        interactive: false
      }).addTo(map);
    },
    setLineLength({ lineId, field, value }) {
      const line = lineById(lineId);
      if (!line || !["estimated_length", "measured_length"].includes(field)) return;

      line[field] = value;
      sync();
    }
  };

  // DOMの描画後に地図サイズを再計算する
  requestAnimationFrame(() => {
    requestAnimationFrame(() => map.invalidateSize());
  });

  // 現在地が取得できた場合はマーカーを表示する
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition((position) => {
      const { latitude, longitude } = position.coords;

      if (!japanBounds.contains([latitude, longitude])) return;

      const currentLocationIcon = L.divIcon({
        className: "current-location-marker",
        html: '<div class="marker-pin"></div>',
        iconSize: [30, 30],
        iconAnchor: [15, 15]
      });

      map.setView([latitude, longitude], 16);
      L.marker([latitude, longitude], { icon: currentLocationIcon }).addTo(map);
    });
  }
}

document.addEventListener("turbo:load", () => {
  initializeMap();
});
