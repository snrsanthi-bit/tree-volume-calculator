# frozen_string_literal: true

# 見積の画面から作業範囲の画面へ来たときに、保存後も取り込み先の見積を引き継ぐ。
# 取り込み先は、'new'（新しい見積を作る）か、見積のID（数字）。それ以外の値は無視する。
# セッションには持たない（別のタブで別の見積から来ても、混ざらないように、フォームの値で引き継ぐ）。
module EstimateImportTarget
  extend ActiveSupport::Concern

  included do
    # params を読むだけなので、アクションは絞らない（絞ると、concern にないアクション名を書くことになる）
    before_action :set_return_estimate_id
  end

  private

  def import_estimate_param
    value = params[:estimate_id].to_s
    value if value == 'new' || value.match?(/\A\d+\z/)
  end

  # 取り込み先のプルダウンの初期値。空 = 新しい見積を作る
  def import_estimate_selection
    import_estimate_param == 'new' ? '' : import_estimate_param.to_s
  end

  def set_return_estimate_id
    @return_estimate_id = import_estimate_param
  end
end
