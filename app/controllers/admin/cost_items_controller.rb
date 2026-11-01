# frozen_string_literal: true

module Admin
  # 単価マスタ（人工・機械・処分など、見積の明細に足す項目と単価）を管理する。会社ごと。
  # 他社の項目は find で見つからず 404 になる。他社の区分を指定すると、入力エラーになる。
  class CostItemsController < BaseController
    before_action :set_cost_item, only: %i[edit update destroy]
    before_action :load_categories, only: %i[index new create edit update]
    before_action :require_categories, only: :new

    def index; end

    def new
      @cost_item = items.new
    end

    def edit; end

    def create
      @cost_item = items.new(cost_item_params)

      if @cost_item.save
        redirect_to admin_cost_items_path, notice: t('.success', default: '項目を追加しました')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @cost_item.update(cost_item_params)
        redirect_to admin_cost_items_path, notice: t('.success', default: '項目を更新しました')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @cost_item.destroy!
      redirect_to admin_cost_items_path, notice: t('.success', default: '項目を削除しました'), status: :see_other
    end

    private

    def items
      current_user.organization.cost_items
    end

    def load_categories
      @cost_categories = current_user.organization.cost_categories.ordered.includes(:cost_items)
    end

    # 区分がないと項目を足せない。先に区分を登録してもらう
    def require_categories
      return if @cost_categories.any?

      redirect_to admin_cost_categories_path, alert: t('.no_category', default: '先に区分を登録してください')
    end

    def set_cost_item
      @cost_item = items.find(params.expect(:id))
    end

    # 会社(organization_id)は受け付けない。常に自社の項目
    def cost_item_params
      params.expect(cost_item: %i[name cost_category_id unit unit_price])
    end
  end
end
