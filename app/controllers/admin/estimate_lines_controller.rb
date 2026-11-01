# frozen_string_literal: true

module Admin
  # 見積の明細の追加・数量と単価の変更・削除。画面は Turbo Stream で、集計だけを更新する。
  # 他社の見積・単価マスタの項目は find で見つからず 404 になる。
  class EstimateLinesController < BaseController
    before_action :set_estimate
    before_action :set_estimate_line, only: %i[update destroy]

    def create
      cost_item = current_user.organization.cost_items.find(create_params[:cost_item_id])
      @estimate_line = EstimateLine.from_cost_item(@estimate, cost_item, create_params[:quantity])

      respond_after(@estimate_line.save)
    end

    def update
      respond_after(@estimate_line.update(update_params))
    end

    def destroy
      @estimate_line.destroy!

      respond_after(true)
    end

    private

    # Turbo Stream なら画面の一部だけを更新し、そうでなければ見積の画面へ戻る
    def respond_after(saved)
      respond_to do |format|
        format.turbo_stream { render status: saved ? :ok : :unprocessable_content }
        format.html { redirect_to admin_estimate_path(@estimate), **html_flash(saved) }
      end
    end

    def html_flash(saved)
      return { status: :see_other } if saved

      { status: :see_other, alert: @estimate_line.errors.full_messages.join(' ') }
    end

    def set_estimate
      @estimate = current_user.organization.estimates.find(params.expect(:estimate_id))
    end

    def set_estimate_line
      @estimate_line = @estimate.estimate_lines.find(params.expect(:id))
    end

    def create_params
      params.expect(estimate_line: %i[cost_item_id quantity])
    end

    # 名前・区分・単位は変えられない。数量と単価だけ（この見積の中だけで変わる）
    def update_params
      params.expect(estimate_line: %i[quantity unit_price])
    end
  end
end
