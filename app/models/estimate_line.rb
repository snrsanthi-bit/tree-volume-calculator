# frozen_string_literal: true

# 見積の明細。単価マスタの項目から足した時点の名前・区分・単位・単価をコピーして持つ。
# 数量と単価は、この見積の中だけで変えられる（単価マスタには影響しない）。
class EstimateLine < ApplicationRecord
  include NumericInput

  MAX_QUANTITY = 1_000_000

  belongs_to :estimate
  belongs_to :cost_category

  normalize_numeric_input :quantity, :unit_price

  validates :name, presence: true, length: { maximum: 50 }
  validates :unit, presence: true, length: { maximum: 10 }
  validates :quantity, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_QUANTITY }
  validates :unit_price, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: CostItem::MAX_UNIT_PRICE
  }
  validate :category_belongs_to_organization

  # 単価マスタの項目から、明細を作る（まだ保存しない）。数量が空なら1。
  def self.from_cost_item(estimate, cost_item, quantity)
    estimate.estimate_lines.new(
      name: cost_item.name, cost_category: cost_item.cost_category, unit: cost_item.unit,
      unit_price: cost_item.unit_price, quantity: quantity.presence || 1
    )
  end

  # 明細の金額（円）。円未満は四捨五入する（EstimateCalculator と同じ規則）
  def amount
    (quantity.to_r * unit_price.to_i).round(half: :up)
  end

  private

  # 他社の区分は指定できない
  def category_belongs_to_organization
    return if cost_category.nil? || cost_category.organization_id == estimate&.organization_id

    errors.add(:cost_category, :invalid)
  end
end
