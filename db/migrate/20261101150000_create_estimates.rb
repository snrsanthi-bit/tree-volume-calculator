# frozen_string_literal: true

# 見積。作成時点の見積の設定（利益率・諸経費率・端数）を、見積自身にコピーして持つ。
# あとで会社の設定を変えても、作成済みの見積の金額は変わらない。
class CreateEstimates < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :estimates do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :area, precision: 12, scale: 2
      t.decimal :overhead_rate, precision: 5, scale: 2, null: false
      t.decimal :margin_rate, precision: 5, scale: 2, null: false
      t.integer :margin_basis, null: false
      t.integer :rounding_unit, null: false
      t.integer :rounding_mode, null: false
      t.decimal :area_price_rounding_unit, precision: 4, scale: 1, null: false

      t.timestamps
    end
  end
end
