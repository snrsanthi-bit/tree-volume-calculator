# frozen_string_literal: true

module Admin
  # 自社の見積の設定（利益率・諸経費率・端数）を編集する。設定は会社に1つで、常に自社のものだけを扱う。
  # まだ設定がない会社は、初めて開いたときに初期値で作る。
  class EstimateSettingsController < BaseController
    before_action :set_estimate_setting

    def edit; end

    def update
      if @estimate_setting.update(estimate_setting_params)
        redirect_to edit_admin_estimate_setting_path, notice: t('.success', default: '見積の設定を保存しました')
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_estimate_setting
      @estimate_setting = EstimateSetting.for(current_user.organization)
    end

    # 会社(organization_id)は受け付けない。常に自社の設定
    def estimate_setting_params
      params.expect(
        estimate_setting: %i[overhead_rate margin_rate margin_basis rounding_unit rounding_mode
                             area_price_rounding_unit]
      )
    end
  end
end
