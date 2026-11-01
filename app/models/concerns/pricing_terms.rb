# frozen_string_literal: true

# 見積の条件（利益率・諸経費率・端数）。
# 会社の設定（EstimateSetting）と、見積ごとのコピー（Estimate）が、同じ項目と同じ検証を持つ。
module PricingTerms
  extend ActiveSupport::Concern

  # 会社の設定から見積へコピーする項目
  FIELDS = %w[overhead_rate margin_rate margin_basis rounding_unit rounding_mode area_price_rounding_unit].freeze
  ROUNDING_UNITS = [1, 10, 100, 1000].freeze
  # ㎡単価（売価 ÷ 面積）の端数の単位（円）
  AREA_PRICE_ROUNDING_UNITS = [BigDecimal('0.1'), BigDecimal(1), BigDecimal(10)].freeze

  included do
    include NumericInput

    # sales = 売価に対する利益率 / cost = 原価に上乗せ
    enum :margin_basis, { sales: 0, cost: 1 }, prefix: true, validate: true, default: :sales
    # ceil = 切り上げ / round = 四捨五入 / floor = 切り捨て
    enum :rounding_mode, { ceil: 0, round: 1, floor: 2 }, prefix: true, validate: true, default: :ceil

    normalize_numeric_input :overhead_rate, :margin_rate, :rounding_unit, :area_price_rounding_unit

    validates :overhead_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validates :margin_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 999 }
    validates :rounding_unit, inclusion: { in: ROUNDING_UNITS }
    validates :area_price_rounding_unit, inclusion: { in: AREA_PRICE_ROUNDING_UNITS }
    validate :margin_rate_below_100_on_sales
  end

  # 金額計算（EstimateCalculator）に渡す設定
  def to_calculator_settings
    EstimateCalculator::Settings.new(
      overhead_rate:, margin_rate:, margin_basis: margin_basis.to_sym,
      rounding_unit:, rounding_mode: rounding_mode.to_sym
    )
  end

  private

  # 売価に対する利益率は100%未満（100%以上だと売価が決まらない）
  def margin_rate_below_100_on_sales
    return if margin_rate.nil? || !margin_basis_sales?

    errors.add(:margin_rate, :less_than, count: 100) if margin_rate >= 100
  end
end
