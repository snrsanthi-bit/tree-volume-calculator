# frozen_string_literal: true

# 見積の明細。単価マスタの項目から足した時点の名前・単位・単価をコピーして持つ。
# あとで単価マスタを変えても、作成済みの見積の金額は変わらない。
class CreateEstimateLines < ActiveRecord::Migration[8.1]
  def change
    create_table :estimate_lines do |t|
      t.references :estimate, null: false, foreign_key: true
      t.references :cost_category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :unit, null: false
      t.decimal :quantity, precision: 12, scale: 2, null: false, default: 0
      t.integer :unit_price, null: false, default: 0

      t.timestamps
    end
  end
end
