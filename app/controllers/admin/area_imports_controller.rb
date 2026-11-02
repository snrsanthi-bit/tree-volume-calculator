# frozen_string_literal: true

module Admin
  # 作業範囲の画面で表示している地積(㎡。実測または地図上の概算)を、既存の見積の面積に取り込む。
  # 取り込み先を選ばないときは、作業範囲の名前で新しい見積を作る。
  # 他社の見積・作業範囲は find で見つからず 404 になる。
  # 地積はブラウザで計算した値で、サーバーでは検証しない（手で直せる参考値として扱う）。
  class AreaImportsController < BaseController
    def create
      if estimate.import_area(work_area, import_params[:area], kind)
        redirect_to admin_estimate_path(estimate), status: :see_other, notice: success_message
      else
        redirect_to failure_path, status: :see_other, alert: estimate.errors.full_messages.join(' ')
      end
    end

    private

    def kind
      import_params[:kind].presence || 'measured'
    end

    # 失敗したら作業範囲の画面へ戻す。選んでいた取り込み先は、そのまま選んでおく
    def failure_path
      work_area_path(work_area, estimate_id: import_params[:estimate_id].presence || 'new')
    end

    def work_area
      @work_area ||= current_user.organization.work_areas.find(import_params[:work_area_id])
    end

    # 取り込み先が空なら、作業範囲の名前で新しい見積を作って取り込む（名前はあとで直せる）
    def estimate
      @estimate ||= if import_params[:estimate_id].present?
                      current_user.organization.estimates.find(import_params[:estimate_id])
                    else
                      Estimate.build_for(current_user.organization, name: work_area.name.to_s.first(50))
                    end
    end

    def success_message
      t('.success', default: '地積を見積の面積に取り込みました')
    end

    def import_params
      params.expect(area_import: %i[estimate_id work_area_id area kind])
    end
  end
end
