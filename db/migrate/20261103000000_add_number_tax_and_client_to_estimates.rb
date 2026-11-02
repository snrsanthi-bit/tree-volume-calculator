# frozen_string_literal: true

# 見積番号・宛名・消費税。
# 設定（estimate_settings）に、番号の接頭辞・番号の最後の値・税率・消費税の端数の処理を持つ。
# 見積（estimates）には、作成時点の接頭辞・税率・端数の処理をコピーして持つ（あとで設定を変えても変わらない）。
class AddNumberTaxAndClientToEstimates < ActiveRecord::Migration[8.1]
  def change
    change_settings
    change_estimates
  end

  private

  def change_settings
    change_table :estimate_settings, bulk: true do |t|
      t.string :number_prefix, null: false, default: '見積-'
      t.integer :last_estimate_number, null: false, default: 0
      t.decimal :tax_rate, precision: 5, scale: 2, null: false, default: 10
      t.integer :tax_rounding_mode, null: false, default: 2
    end
  end

  def change_estimates
    change_table :estimates, bulk: true do |t|
      t.integer :number
      t.string :number_prefix, null: false, default: '見積-'
      t.string :client_name
      t.decimal :tax_rate, precision: 5, scale: 2, null: false, default: 10
      t.integer :tax_rounding_mode, null: false, default: 2
    end
  end
end
