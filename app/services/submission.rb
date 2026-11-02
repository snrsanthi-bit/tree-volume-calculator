# frozen_string_literal: true

# 元請けに出す見積書の内容。「書いてあること」だけを持ち、書式（見た目）は持たない。
# 原価・利益率・利益は持たない。提出画面は、この値だけから作る（見えてはいけない値を、画面に渡さないため）。
#
#   format     : :breakdown（項目別の内訳）/ :area_price（㎡単価）
#   price      : 金額（税抜）、tax: 消費税、total: 税込
#   rows       : 明細の行（Submission::Row）。空のとき problem に理由がある
#   area_price : ㎡単価の形式のときだけ。単価 × 面積と金額の差を、確認用に持つ
#   problem    : 提出書を作れない理由（なければ nil）
Submission = Struct.new(
  :number_label, :site_name, :client_name, :issued_on, :issuer, :note, :format,
  :price, :tax_rate, :tax, :total, :rows, :area_price, :problem,
  keyword_init: true
)

# 提出書に載せる自社の情報
Submission::Issuer = Struct.new(:name, :address, :phone, keyword_init: true)

# 明細の1行。項目別の内訳では、数量・単位・単価は空
Submission::Row = Struct.new(:name, :quantity, :unit, :unit_price, :amount, keyword_init: true)

# ㎡単価の確認用。product は単価 × 面積（円）、difference は金額との差
Submission::AreaPrice = Struct.new(:area, :unit_price, :product, :difference, keyword_init: true)
