# frozen_string_literal: true

module Admin
  # 見積の内訳の区分（伐採費・整理費など）を管理する。会社ごと。
  # 他社の区分は find で見つからず 404 になる。単価マスタや見積の明細で使われている区分は削除できない。
  class CostCategoriesController < BaseController
    before_action :set_cost_category, only: %i[edit update destroy]

    def index
      @cost_category = categories.new
      @cost_categories = ordered_categories
    end

    def edit; end

    def create
      @cost_category = categories.new(cost_category_params)

      if @cost_category.save
        redirect_to admin_cost_categories_path, notice: t('.success', default: '区分を追加しました')
      else
        @cost_categories = ordered_categories
        render :index, status: :unprocessable_content
      end
    end

    def update
      if @cost_category.update(cost_category_params)
        redirect_to admin_cost_categories_path, notice: t('.success', default: '区分を更新しました')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @cost_category.destroy
        redirect_to admin_cost_categories_path, notice: t('.success', default: '区分を削除しました'), status: :see_other
      else
        message = t('.failure', default: 'この区分は単価マスタか見積で使われているため削除できません')
        redirect_to admin_cost_categories_path, alert: message, status: :see_other
      end
    end

    private

    def categories
      current_user.organization.cost_categories
    end

    def ordered_categories
      categories.ordered.includes(:cost_items)
    end

    def set_cost_category
      @cost_category = categories.find(params.expect(:id))
    end

    # 会社(organization_id)は受け付けない。常に自社の区分
    def cost_category_params
      params.expect(cost_category: %i[name])
    end
  end
end
