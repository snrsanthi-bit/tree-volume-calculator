# frozen_string_literal: true

# 見積の内訳の区分（伐採費・整理費・機械費・処分費など）。会社ごと。
class CreateCostCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :cost_categories do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :cost_categories, %i[organization_id name], unique: true
  end
end
