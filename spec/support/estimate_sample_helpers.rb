# frozen_string_literal: true

# 見積のspecで使う、サンプルの見積を作る。
# 直接費 619,000円 + 諸経費5% = 原価 649,950円。利益率30%（売価に対して）・1,000円単位の切り上げで、売価 929,000円。
module EstimateSampleHelpers
  SAMPLE_LINES = [
    { category: '伐採費', name: '伐採 人工', unit: '人日', quantity: 6, unit_price: 28_000 },
    { category: '整理費', name: '整理 人工', unit: '人日', quantity: 4, unit_price: 24_000 },
    { category: '機械費', name: 'バックホウ', unit: '日', quantity: 3, unit_price: 48_000 },
    { category: '機械費', name: 'チェーンソー等 消耗', unit: '日', quantity: 6, unit_price: 6_000 },
    { category: '処分費', name: '産廃処分', unit: '台', quantity: 5, unit_price: 35_000 }
  ].freeze

  def create_sample_estimate(organization, name: '北側作業範囲')
    EstimateSetting.for(organization).update!(overhead_rate: 5, margin_rate: 30)
    estimate = Estimate.build_for(organization, name: name, area: 8420)
    estimate.save!
    SAMPLE_LINES.each { |attributes| add_sample_line(estimate, attributes) }
    estimate
  end

  private

  def add_sample_line(estimate, attributes)
    category = estimate.organization.cost_categories.find_or_create_by!(name: attributes[:category])

    estimate.estimate_lines.create!(attributes.except(:category).merge(cost_category: category))
  end
end
