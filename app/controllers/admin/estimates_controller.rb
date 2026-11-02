# frozen_string_literal: true

module Admin
  # 見積の作成・編集・削除と、見積の画面（明細と集計）。会社ごと。
  # 他社の見積は find で見つからず 404 になる。見積は、作成時点の見積の設定をコピーして持つ。
  class EstimatesController < BaseController
    before_action :set_estimate, only: %i[show edit update destroy]
    before_action :set_work_areas, only: %i[show new create]

    def index
      @estimates = estimates.includes(:estimate_lines).order(id: :desc)
    end

    def show
      @cost_categories = current_user.organization.cost_categories.ordered.includes(:cost_items)
    end

    def new
      @estimate = Estimate.build_for(current_user.organization)
      @area_unit = default_area_unit
    end

    def edit
      @area_unit = default_area_unit
    end

    def create
      @estimate = Estimate.build_for(current_user.organization)
      assign_attributes(@estimate)

      if @estimate.save
        redirect_to admin_estimate_path(@estimate),
                    notice: t('.success', default: '見積を作成しました。明細を足してください')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      assign_attributes(@estimate)

      if @estimate.save
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

    # 名前と面積だけを入れる。面積は、選んだ単位（㎡ / ha）から㎡にして入れる。
    # 会社(organization_id)と、コピーした設定は受け付けない
    def assign_attributes(estimate)
      attributes = estimate_params
      @area_unit = Estimate::AREA_UNITS.include?(attributes[:area_unit]) ? attributes[:area_unit] : 'm2'

      estimate.name = attributes[:name]
      estimate.assign_area(attributes[:area], attributes[:area_unit]) if attributes.key?(:area)
    end

    # 地積の取り込み元として並べる、自社の作業範囲（新しい順）
    def set_work_areas
      @work_areas = current_user.organization.work_areas.order(id: :desc).limit(20)
    end

    def default_area_unit
      EstimateSetting.for(current_user.organization).area_input_unit
    end

    def estimate_params
      params.expect(estimate: %i[name area area_unit])
    end
  end
end
