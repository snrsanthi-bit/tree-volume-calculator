import { Controller } from "@hotwired/stimulus"

// ボタンを押すと、ブラウザの印刷画面を開く。印刷画面の送信先を「PDFに保存」にすると、PDFができる。
//
//   <button type="button" data-controller="print" data-action="print#print">印刷</button>
export default class extends Controller {
  print() {
    window.print()
  }
}
