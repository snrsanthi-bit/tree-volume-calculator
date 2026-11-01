# frozen_string_literal: true

# ㎡単価（売価 ÷ 面積）の端数の単位（円）。0.1 / 1 / 10 のどれか。
class AddAreaPriceRoundingUnitToEstimateSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :estimate_settings, :area_price_rounding_unit, :decimal, precision: 4, scale: 1, null: false, default: 1
  end
end
