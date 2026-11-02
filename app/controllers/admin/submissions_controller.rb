# frozen_string_literal: true

module Admin
  # 提出画面。元請けに出す内容のプレビューと、提出の形式（項目別の内訳 / ㎡単価）の切り替え。
  # PDF は、ブラウザの印刷（PDFに保存）で出す。他社の見積は find で見つからず 404 になる。
  class SubmissionsController < BaseController
    layout 'submission'

    before_action :set_estimate

    def show
      @submission = SubmissionBuilder.call(@estimate)
    end

    def update
      saved = @estimate.update(submission_params)
      flash_options = saved ? {} : { alert: t('.invalid_format', default: '提出の形式が正しくありません') }

      redirect_to admin_estimate_submission_path(@estimate), status: :see_other, **flash_options
    end

    private

    def set_estimate
      @estimate = current_user.organization.estimates.find(params.expect(:estimate_id))
    end

    # 形式だけを受け付ける（金額や会社は、ここからは変えられない）
    def submission_params
      params.expect(estimate: %i[submission_format])
    end
  end
end
