// 測量データの純粋なロジック（DOM・Leaflet に依存しない）
//
// 保存するのは「点」と「線」だけ。三角形（面）は必要なときに導出する。
//
//   point: { id, lat, lng, origin }          origin: "input"(外周点モードで置いた点) | "worker"(補助点)
//   line : { id, from, to, origin,           origin: "proposed"(ロジックが作った線) | "worker"(作業者が引いた線)
//            estimated_length, measured_length }

const EPS_AREA = 1e-6; // m²
const EPS_ON_LINE = 0.05; // m（点が線の上にあるとみなす距離）

export function round1(value) {
  return Math.round(value * 10) / 10;
}

export function pairKey(a, b) {
  return [a, b].sort().join("|");
}

export function nextNumericId(prefix, items) {
  const max = items.reduce((result, item) => {
    const number = Number(String(item.id).replace(prefix, ""));
    return Number.isInteger(number) ? Math.max(result, number) : result;
  }, 0);

  return max + 1;
}

export function distanceMeters(a, b) {
  const toRad = (degrees) => (degrees * Math.PI) / 180;
  const earthRadius = 6371000;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;

  return 2 * earthRadius * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

// 緯度経度 → 平面(m)。範囲が狭い作業範囲なので、等距円筒で十分
function projector(points) {
  const lat0 = points.reduce((sum, p) => sum + p.lat, 0) / (points.length || 1);
  const lng0 = points.reduce((sum, p) => sum + p.lng, 0) / (points.length || 1);
  const kx = Math.cos((lat0 * Math.PI) / 180) * 111320;
  const ky = 110540;

  return (p) => ({ x: (p.lng - lng0) * kx, y: (p.lat - lat0) * ky });
}

function cross(o, a, b) {
  return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
}

function properlyCross(a, b, c, d) {
  return cross(a, b, c) * cross(a, b, d) < 0 && cross(c, d, a) * cross(c, d, b) < 0;
}

function distanceToSegment(p, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const lengthSquared = dx * dx + dy * dy;
  const t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared;

  if (t <= 0 || t >= 1) return { distance: Infinity, t };

  const px = a.x + t * dx;
  const py = a.y + t * dy;
  return { distance: Math.hypot(p.x - px, p.y - py), t };
}

// ロジックの三角分割結果（座標の三角形）から、点IDを参照する線を作る
export function buildFromTriangles(points, triangles, startId = 1) {
  const key = (lat, lng) => `${Number(lat).toFixed(9)},${Number(lng).toFixed(9)}`;
  const idByCoordinate = new Map(points.map((p) => [key(p.lat, p.lng), p.id]));
  const byId = new Map(points.map((p) => [p.id, p]));
  const pairs = new Map();

  triangles.forEach((triangle) => {
    const ids = triangle.map(([lat, lng]) => idByCoordinate.get(key(lat, lng)));

    if (ids.some((id) => id === undefined)) {
      throw new Error("三角分割の頂点が外周点と一致しません");
    }

    ids.forEach((from, index) => {
      const to = ids[(index + 1) % 3];
      const k = pairKey(from, to);

      if (!pairs.has(k)) pairs.set(k, { from, to });
    });
  });

  return [...pairs.values()].map(({ from, to }, index) => ({
    id: `l-${startId + index}`,
    from,
    to,
    origin: "proposed",
    estimated_length: round1(distanceMeters(byId.get(from), byId.get(to))),
    measured_length: null
  }));
}

// ---- 実測値の引き継ぎ ---------------------------------------------------
// 線の同一性は「両端点の座標」で判断する（点IDや線IDは作り直しで変わるため）。
// 端点の順序は問わない。片方の端点でも座標が動いた線は別の線として扱う。
function coordinateKey(point) {
  return `${Number(point.lat).toFixed(9)},${Number(point.lng).toFixed(9)}`;
}

export function lineCoordinateKey(line, pointsById) {
  const from = pointsById.get(line.from);
  const to = pointsById.get(line.to);

  if (!from || !to) return null;

  return pairKey(coordinateKey(from), coordinateKey(to));
}

export function hasMeasured(line) {
  return line.measured_length !== null && line.measured_length !== undefined;
}

// 作り直す前の線（oldLines / oldPoints）の実測値を、座標が一致する新しい線へ引き継ぐ。
// 戻り値: lines = 実測値を引き継いだ新しい線 / lostCount = 引き継げず消える実測値の数
export function carryOverMeasurements(oldLines, oldPoints, newLines, newPoints) {
  const oldById = new Map(oldPoints.map((p) => [p.id, p]));
  const newById = new Map(newPoints.map((p) => [p.id, p]));
  const measuredByKey = new Map();

  oldLines.filter(hasMeasured).forEach((line) => {
    const key = lineCoordinateKey(line, oldById);

    if (key) measuredByKey.set(key, line.measured_length);
  });

  const used = new Set();

  const lines = newLines.map((line) => {
    const key = lineCoordinateKey(line, newById);

    if (!key || !measuredByKey.has(key) || used.has(key)) return line;

    used.add(key);
    return { ...line, measured_length: measuredByKey.get(key) };
  });

  const measuredCount = oldLines.filter(hasMeasured).length;

  return { lines, lostCount: measuredCount - used.size };
}

// new の提案だけを切り出す（将来 new と edit の差分を取るための基準）
export function snapshotProposed(points, lines) {
  return {
    points: points.filter((p) => p.origin === "input").map((p) => ({ ...p })),
    lines: lines.filter((l) => l.origin === "proposed").map((l) => ({ ...l }))
  };
}

export function pointInPolygon(point, polygon) {
  let inside = false;

  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i];
    const b = polygon[j];
    const crosses =
      a.lat > point.lat !== b.lat > point.lat &&
      point.lng < ((b.lng - a.lng) * (point.lat - a.lat)) / (b.lat - a.lat) + a.lng;

    if (crosses) inside = !inside;
  }

  return inside;
}

function error(type, message, lineIds = [], pointIds = []) {
  return { type, message, lineIds, pointIds };
}

function findGeometryErrors(lines, projected, points) {
  const errors = [];

  lines.forEach((first, i) => {
    for (let j = i + 1; j < lines.length; j++) {
      const second = lines[j];
      const shared = [first.from, first.to].some((id) => id === second.from || id === second.to);

      if (shared) continue;

      if (properlyCross(projected.get(first.from), projected.get(first.to),
                        projected.get(second.from), projected.get(second.to))) {
        errors.push(error("crossing", "線が交差しています。赤くなっている線を修正してください", [first.id, second.id]));
      }
    }
  });

  lines.forEach((line) => {
    points.forEach((point) => {
      if (point.id === line.from || point.id === line.to) return;

      const { distance } = distanceToSegment(projected.get(point.id), projected.get(line.from), projected.get(line.to));

      if (distance < EPS_ON_LINE) {
        errors.push(error("point_on_line", "線の途中に点があります。点で線を分けてください", [line.id], [point.id]));
      }
    });
  });

  return errors;
}

// 各点から出る線を角度順に並べて、半辺をたどり「面」を列挙する
function enumerateFaces(lines, projected) {
  const neighbors = new Map();
  const lineIdByPair = new Map(lines.map((l) => [pairKey(l.from, l.to), l.id]));

  lines.forEach((line) => {
    [[line.from, line.to], [line.to, line.from]].forEach(([a, b]) => {
      if (!neighbors.has(a)) neighbors.set(a, []);
      neighbors.get(a).push(b);
    });
  });

  neighbors.forEach((list, id) => {
    const origin = projected.get(id);
    list.sort((p, q) => {
      const a = projected.get(p);
      const b = projected.get(q);
      return Math.atan2(a.y - origin.y, a.x - origin.x) - Math.atan2(b.y - origin.y, b.x - origin.x);
    });
  });

  const visited = new Set();
  const faces = [];
  const halfKey = (a, b) => `${a}>${b}`;

  lines.forEach((line) => {
    [[line.from, line.to], [line.to, line.from]].forEach(([startA, startB]) => {
      if (visited.has(halfKey(startA, startB))) return;

      const cycle = [];
      let [a, b] = [startA, startB];

      for (let guard = 0; guard <= lines.length * 2; guard++) {
        visited.add(halfKey(a, b));
        cycle.push(a);

        const list = neighbors.get(b);
        const next = list[(list.indexOf(a) - 1 + list.length) % list.length];
        [a, b] = [b, next];

        if (halfKey(a, b) === halfKey(startA, startB)) break;
      }

      const area = cycle.reduce((sum, id, index) => {
        const p = projected.get(id);
        const q = projected.get(cycle[(index + 1) % cycle.length]);
        return sum + (p.x * q.y - q.x * p.y) / 2;
      }, 0);

      const lineIds = cycle.map((id, index) => lineIdByPair.get(pairKey(id, cycle[(index + 1) % cycle.length])));

      faces.push({ pointIds: cycle, lineIds, area });
    });
  });

  return faces;
}

// points + lines を検査し、三角形・外周・エラーを返す
//   ok        : 地積を出せる状態か（交差なし／全ての面が三角形）
//   triangles : 3辺の面 [{ pointIds, lineIds, area(地図上の概算 m²) }]
//   outline   : 外周の点ID（反時計回り）。導出できないときは null
//   errors    : 優先度順。先頭の種類のものを作業者に提示する
export function analyze(points, lines) {
  const result = { ok: false, errors: [], triangles: [], outline: null };
  const byId = new Map(points.map((p) => [p.id, p]));
  const errors = result.errors;

  const brokenLines = lines.filter((l) => !byId.has(l.from) || !byId.has(l.to) || l.from === l.to);

  if (brokenLines.length > 0) {
    errors.push(error("reference", "存在しない点を参照している線があります", brokenLines.map((l) => l.id)));
    return result;
  }

  const projected = new Map();
  const project = projector(points);
  points.forEach((p) => projected.set(p.id, project(p)));

  const geometryErrors = findGeometryErrors(lines, projected, points);

  if (geometryErrors.length > 0) {
    errors.push(...geometryErrors);
    return result;
  }

  const degree = new Map(points.map((p) => [p.id, 0]));
  lines.forEach((l) => {
    degree.set(l.from, degree.get(l.from) + 1);
    degree.set(l.to, degree.get(l.to) + 1);
  });

  const isolated = points.filter((p) => degree.get(p.id) === 0).map((p) => p.id);

  if (isolated.length > 0) {
    errors.push(error("isolated", "線につながっていない点があります。線を引くか、点を削除してください", [], isolated));
  }

  const dangling = points.filter((p) => degree.get(p.id) === 1);

  if (dangling.length > 0) {
    const ids = dangling.map((p) => lines.find((l) => l.from === p.id || l.to === p.id).id);
    errors.push(error("dangling", "行き止まりの線があります。三角形を作らない線は引けません", ids, dangling.map((p) => p.id)));
  }

  if (lines.length === 0) {
    errors.push(error("outline", "外周が閉じていません。3点以上の外周が必要です"));
    return result;
  }

  if (!isConnected(lines)) {
    errors.push(error("disconnected", "つながっていない線のかたまりがあります", lines.map((l) => l.id)));
    return result;
  }

  const faces = enumerateFaces(lines, projected);
  const outerFaces = faces.filter((f) => f.area < -EPS_AREA);
  const innerFaces = faces.filter((f) => f.area > EPS_AREA);

  if (outerFaces.length !== 1) {
    errors.push(error("outline", "外周が閉じていません。外周の線を確認してください"));
    return result;
  }

  const outer = outerFaces[0];

  if (new Set(outer.pointIds).size !== outer.pointIds.length) {
    errors.push(error("outline_pinch", "外周が1点で接している、または外周から飛び出した線があります", outer.lineIds, []));
  } else {
    result.outline = [...outer.pointIds].reverse();
  }

  innerFaces.forEach((face) => {
    if (face.pointIds.length === 3) {
      result.triangles.push(face);
    } else {
      errors.push(error("not_triangle", "三角形になっていない領域があります。補助線を足して三角形に分割してください", face.lineIds, face.pointIds));
    }
  });

  result.ok = errors.length === 0;
  return result;
}

function isConnected(lines) {
  const adjacency = new Map();

  lines.forEach((l) => {
    [[l.from, l.to], [l.to, l.from]].forEach(([a, b]) => {
      if (!adjacency.has(a)) adjacency.set(a, []);
      adjacency.get(a).push(b);
    });
  });

  const start = lines[0].from;
  const seen = new Set([start]);
  const queue = [start];

  while (queue.length > 0) {
    adjacency.get(queue.shift()).forEach((next) => {
      if (!seen.has(next)) {
        seen.add(next);
        queue.push(next);
      }
    });
  }

  return seen.size === adjacency.size;
}

export function triangleArea(a, b, c) {
  const s = (a + b + c) / 2;
  const value = s * (s - a) * (s - b) * (s - c);

  return value > 0 ? Math.sqrt(value) : null;
}

// 三角形ごとに3辺の長さからヘロンの公式で面積を出し、合計する
//   field: "measured_length"(実測) | "estimated_length"(概算)
//   details[i].status: "ok" | "missing"(未入力) | "invalid"(三角形が成立しない)
export function computeArea(triangles, lines, field = "measured_length") {
  const byId = new Map(lines.map((l) => [l.id, l]));
  let total = 0;

  const details = triangles.map((triangle) => {
    const [a, b, c] = triangle.lineIds.map((id) => byId.get(id)?.[field]);

    if (![a, b, c].every((v) => Number.isFinite(v) && v > 0)) {
      return { status: "missing", area: null };
    }

    const area = triangleArea(a, b, c);

    if (area === null || a + b <= c || a + c <= b || b + c <= a) {
      return { status: "invalid", area: null };
    }

    total += area;
    return { status: "ok", area };
  });

  const complete = triangles.length > 0 && details.every((d) => d.status === "ok");

  return { complete, total: complete ? total : null, details };
}
