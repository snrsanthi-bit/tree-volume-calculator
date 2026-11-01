# frozen_string_literal: true

module Admin
  # 見積の作成・編集・削除と、見積の画面（明細と集計）。会社ごと。
  # 他社の見積は find で見つからず 404 になる。見積は、作成時点の見積の設定をコピーして持つ。
  class EstimatesController < BaseController
    before_action :set_estimate, only: %i[show edit update destroy]

    def index
      @estimates = estimates.includes(:estimate_lines).order(id: :desc)
    end

    def show
      @cost_categories = current_user.organization.cost_categories.ordered.includes(:cost_items)
    end

    def new
      @estimate = Estimate.build_for(current_user.organization)
    end

    def edit; end

    def create
      @estimate = Estimate.build_for(current_user.organization, estimate_params.to_h)

      if @estimate.save
        redirect_to admin_estimate_path(@estimate),
                    notice: t('.success', default: '見積を作成しました。明細を足してください')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @estimate.update(estimate_params)
        redirect_to admin_estimate_path(@estimate), notice: t('.success', default: '見積を更新しました')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @estimate.destroy!
      redirect_to admin_estimates_path, notice: t('.success', default: '見積を削除しました'), status: :see_other
    end

    private

    def estimates
      current_user.organization.estimates
    end

    def set_estimate
      @estimate = estimates.find(params.expect(:id))
    end

    # 会社(organization_id)と、コピーした設定は受け付ける項目に含めない
    def estimate_params
      params.expect(estimate: %i[name area])
    end
  end
end
