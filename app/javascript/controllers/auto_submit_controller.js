import { Controller } from "@hotwired/stimulus"

// 入力欄の値が変わったら、少し待ってからフォームを自動で送信する。
// 送信すると、Turbo が画面の一部（集計など）だけを更新する。
//
//   <form data-controller="auto-submit" data-action="input->auto-submit#submit">
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
