# frozen_string_literal: true

# 会社ごとの見積の設定（会社に1つ）。
# margin_basis: 0 = 売価に対する利益率 / 1 = 原価に上乗せ
# rounding_mode: 0 = 切り上げ / 1 = 四捨五入 / 2 = 切り捨て
class CreateEstimateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :estimate_settings do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }
      t.decimal :overhead_rate, precision: 5, scale: 2, null: false, default: 0
      t.decimal :margin_rate, precision: 5, scale: 2, null: false, default: 30
      t.integer :margin_basis, null: false, default: 0
      t.integer :rounding_unit, null: false, default: 1000
      t.integer :rounding_mode, null: false, default: 0

      t.timestamps
    end
  end
end
