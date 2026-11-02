# frozen_string_literal: true

# 取り込んだ面積が、実測(0)と概算(1)のどちらか。見積の段階では実測できないので、概算も取り込める
class AddAreaSourceKindToEstimates < ActiveRecord::Migration[8.1]
  def change
    add_column :estimates, :area_source_kind, :integer
  end
end
