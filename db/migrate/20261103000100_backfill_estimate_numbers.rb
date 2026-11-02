# frozen_string_literal: true

# 既存の見積に、会社ごとに作成順（id順）で番号を付ける。付けたあと、番号を必須にして、会社内で重複しないようにする。
class BackfillEstimateNumbers < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE estimates SET number = numbered.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY id) AS rn FROM estimates
      ) AS numbered
      WHERE estimates.id = numbered.id
    SQL
    sync_counters
    change_column_null :estimates, :number, false
    add_index :estimates, %i[organization_id number], unique: true
  end

  def down
    remove_index :estimates, %i[organization_id number]
    change_column_null :estimates, :number, true
  end

  private

  # 設定の「最後の番号」を、会社ごとの最大の番号に合わせる（次の見積が、続きの番号になる）
  def sync_counters
    execute <<~SQL.squish
      UPDATE estimate_settings SET last_estimate_number = COALESCE(
        (SELECT MAX(number) FROM estimates WHERE estimates.organization_id = estimate_settings.organization_id), 0
      )
    SQL
  end
end
