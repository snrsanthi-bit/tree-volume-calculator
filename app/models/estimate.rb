# frozen_string_literal: true

# 見積。会社ごと。作成時点の見積の設定をコピーして持つので、あとで会社の設定を変えても金額は変わらない。
# 金額は、明細から EstimateCalculator で計算する（DBには保存しない）。
class Estimate < ApplicationRecord
  include PricingTerms

  MAX_AREA = 100_000_000

  belongs_to :organization
  has_many :estimate_lines, -> { order(:id) }, dependent: :destroy, inverse_of: :estimate

  normalize_numeric_input :area

  validates :name, presence: true, length: { maximum: 50 }
  validates :area, numericality: { greater_than: 0, less_than_or_equal_to: MAX_AREA }, allow_nil: true

  # 会社の今の設定をコピーして、新しい見積を作る（まだ保存しない）
  def self.build_for(organization, attributes = {})
    setting = EstimateSetting.for(organization)

    organization.estimates.new(setting.slice(*PricingTerms::FIELDS).merge(attributes))
  end

  # 明細と、コピーした設定から、金額を計算する
  def calculation
    lines = estimate_lines.map do |line|
      EstimateCalculator::Line.new(line.cost_category_id, line.quantity, line.unit_price)
    end

    EstimateCalculator.call(lines:, settings: to_calculator_settings)
  end
end
