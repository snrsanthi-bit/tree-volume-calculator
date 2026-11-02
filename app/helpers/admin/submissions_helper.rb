# frozen_string_literal: true

module Admin
  module SubmissionsHelper
    SUBMISSION_FORMAT_LABELS = { 'breakdown' => '項目別の内訳', 'area_price' => '㎡単価' }.freeze
    FORMAT_BUTTON_BASE = 'px-3 py-1.5 rounded-lg border text-sm'

    def submission_format_label(value)
      SUBMISSION_FORMAT_LABELS.fetch(value.to_s, value.to_s)
    end

    # 提出書の日付（例: 2026年11月2日）
    def submission_date_text(date)
      date.strftime('%Y年%-m月%-d日')
    end

    # 面積・数量の表示（例: 8,420 / 8,420.5）
    def area_number_text(value)
      number_with_precision(value, precision: 2, strip_insignificant_zeros: true, delimiter: ',')
    end

    # 単価 × 面積が、金額（税抜）と比べてどうなるか（確認用。提出書には載せない）
    def area_price_gap_text(area_price)
      gap = area_price.difference
      return '金額と一致しています' if gap.zero?

      "金額より#{number_with_delimiter(gap.abs)}円#{gap.negative? ? '多く' : '少なく'}なります"
    end

    # ㎡単価の表示。円未満は、0.1円単位のときだけ出す（例: 110.3 / 111）
    def unit_price_text(value)
      number_with_precision(value, precision: 1, strip_insignificant_zeros: true, delimiter: ',')
    end

    def format_button_class(selected)
      return "#{FORMAT_BUTTON_BASE} border-primary bg-primary text-background-dark font-bold" if selected

      "#{FORMAT_BUTTON_BASE} border-slate-400 bg-white"
    end
  end
end
