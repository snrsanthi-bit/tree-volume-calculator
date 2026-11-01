# frozen_string_literal: true

# 単価マスタの項目（人工・機械・処分など）。会社ごと。単価は整数の円。
class CostItem < ApplicationRecord
  include NumericInput

  MAX_UNIT_PRICE = 100_000_000

  belongs_to :organization
  belongs_to :cost_category

  normalize_numeric_input :unit_price

  validates :name, presence: true, length: { maximum: 50 }
  validates :unit, presence: true, length: { maximum: 10 }
  validates :unit_price, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_UNIT_PRICE
  }
  validate :category_belongs_to_organization

  private

  # 他社の区分は指定できない
  def category_belongs_to_organization
    return if cost_category.nil? || cost_category.organization_id == organization_id

    errors.add(:cost_category, :invalid)
  end
end
