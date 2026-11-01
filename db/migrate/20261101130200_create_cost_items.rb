# frozen_string_literal: true

# 単価マスタ（人工・機械・処分など、見積の明細に足す項目と単価）。会社ごと。単価は整数の円。
class CreateCostItems < ActiveRecord::Migration[8.1]
  def change
    create_table :cost_items do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :cost_category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :unit, null: false
      t.integer :unit_price, null: false, default: 0

      t.timestamps
    end
  end
end
