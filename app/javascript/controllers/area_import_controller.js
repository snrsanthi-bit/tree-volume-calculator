import { Controller } from "@hotwired/stimulus"

// 作業範囲の画面で、表示中の地積(㎡)を、見積に取り込む。
// 見積を作る段階では辺を測っていないので、実測面積のほかに、地図上の概算面積も取り込める。
// 地積は survey_cards.js が #survey-area-measured / #survey-area-estimated の data-total に入れる（計算できないときは空）。
//
//   <section data-controller="area-import" data-action="survey:areas-updated@document->area-import#update">
const SOURCES = {
  measured: { id: "survey-area-measured", label: "実測面積", missing: "すべての辺の長さを入力すると、実測面積を取り込めます" },
  estimated: { id: "survey-area-estimated", label: "概算面積", missing: "概算面積を計算できません" }
}

export default class extends Controller {
  static targets = ["area", "kind", "submit", "message"]

  connect() {
    this.chosen = false
    this.update()
  }

  // 自分で選んだら、あとから実測面積が計算できても、選びなおさない
  choose() {
    this.chosen = true
    this.update()
  }

  update() {
    if (!this.chosen) this.kindTarget.value = this.total("measured") ? "measured" : "estimated"

    const kind = this.kindTarget.value
    const total = this.total(kind)
    const source = SOURCES[kind]

    this.areaTarget.value = total ?? ""
    this.submitTarget.disabled = !total
    this.messageTarget.textContent = total
      ? `取り込む面積: ${Number(total).toLocaleString()} ㎡（いま表示している${source.label}）`
      : source.missing
  }

  total(kind) {
    const value = document.getElementById(SOURCES[kind].id)?.dataset.total

    return value ? value : null
  }
}
