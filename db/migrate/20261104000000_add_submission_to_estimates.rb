# frozen_string_literal: true

# 提出画面。
# 設定（estimate_settings）に、提出書に載せる自社の情報（社名・住所・電話番号・備考）を持つ。
# 見積（estimates）に、提出の形式（0 = 項目別の内訳 / 1 = ㎡単価）を持つ。
class AddSubmissionToEstimates < ActiveRecord::Migration[8.1]
  def change
    change_table :estimate_settings, bulk: true do |t|
      t.string :issuer_name
      t.string :issuer_address
      t.string :issuer_phone
      t.text :submission_note
    end

    add_column :estimates, :submission_format, :integer, null: false, default: 0
  end
end
