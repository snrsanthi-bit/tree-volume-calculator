# frozen_string_literal: true

# 見積の面積を入力するときの単位の初期値（0 = ㎡ / 1 = ha）。保存はどちらも㎡
class AddAreaInputUnitToEstimateSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :estimate_settings, :area_input_unit, :integer, null: false, default: 0
  end
end
