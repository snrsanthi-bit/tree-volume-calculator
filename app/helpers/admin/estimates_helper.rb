# frozen_string_literal: true

module Admin
  module EstimatesHelper
    def yen_text(amount)
      "#{number_with_delimiter(amount)}円"
    end

    # 数量の表示（6.0 → 6、0.5 → 0.5）
    def quantity_text(quantity)
      number_with_precision(quantity, precision: 2, strip_insignificant_zeros: true)
    end

    # 利益率などの表示（%）。値が小数でも、整数でも使える
    def percent_text(value, precision: 1)
      "#{number_with_precision(value, precision:, strip_insignificant_zeros: true)}%"
    end

    def area_text(area)
      return '未入力' if area.nil?

      "#{number_with_precision(area, precision: 2, strip_insignificant_zeros: true, delimiter: ',')}㎡"
    end

    # 見積にコピーされている条件（利益率・諸経費率・端数）の説明
    def terms_text(estimate)
      "利益率 #{percent_text(estimate.margin_rate)}（#{margin_basis_label(estimate.margin_basis)}）、" \
        "諸経費率 #{percent_text(estimate.overhead_rate)}、" \
        "売価の端数は#{number_with_delimiter(estimate.rounding_unit)}円単位で#{rounding_mode_label(estimate.rounding_mode)}"
    end

    # 区分ごとの直接費（区分の並び順）
    def category_subtotals(result)
      CostCategory.where(id: result.category_direct.keys).ordered.map do |category|
        [category.name, result.category_direct[category.id]]
      end
    end

    # 明細を足すプルダウンの選択肢（区分ごとにまとめる。項目のない区分は出さない）
    def cost_item_options(categories)
      categories.reject { |category| category.cost_items.empty? }.map do |category|
        [category.name, category.cost_items.map { |item| [cost_item_label(item), item.id] }]
      end
    end

    def cost_item_label(item)
      "#{item.name}（#{yen_text(item.unit_price)} / #{item.unit}）"
    end

    def estimate_date(estimate)
      estimate.created_at.in_time_zone('Asia/Tokyo').strftime('%Y/%m/%d')
    end
  end
end
