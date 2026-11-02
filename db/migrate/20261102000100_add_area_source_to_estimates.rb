# frozen_string_literal: true

# 地積の取り込み元の作業範囲（任意）と、面積が取り込んだ値のままかどうか。
# 作業範囲が消えても見積は残す（面積の値も残る）。
class AddAreaSourceToEstimates < ActiveRecord::Migration[8.1]
  def change
    add_reference :estimates, :work_area, foreign_key: { on_delete: :nullify }
    add_column :estimates, :area_from_map, :boolean, null: false, default: false
  end
end
