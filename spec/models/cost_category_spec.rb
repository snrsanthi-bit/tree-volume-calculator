# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CostCategory do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }

  it '名前が必要' do
    expect(described_class.new(organization: organization, name: '')).not_to be_valid
  end

  it '名前は30文字まで' do
    expect(described_class.new(organization: organization, name: 'あ' * 31)).not_to be_valid
    expect(described_class.new(organization: organization, name: 'あ' * 30)).to be_valid
  end

  it '同じ会社の中では、名前が重複できない。別の会社なら同じ名前でよい' do
    described_class.create!(organization: organization, name: '伐採費')

    expect(described_class.new(organization: organization, name: '伐採費')).not_to be_valid
    expect(described_class.new(organization: other_organization, name: '伐採費')).to be_valid
  end

  it '新しい区分は、会社の中でいちばん後ろに並ぶ' do
    first = described_class.create!(organization: organization, name: '伐採費')
    second = described_class.create!(organization: organization, name: '整理費')
    other = described_class.create!(organization: other_organization, name: '伐採費')

    expect(second.position).to be > first.position
    expect(other.position).to eq(1)
    expect(organization.cost_categories.ordered.map(&:name)).to eq(%w[伐採費 整理費])
  end

  it '単価マスタの項目が使っている区分は、削除できない' do
    category = described_class.create!(organization: organization, name: '伐採費')
    CostItem.create!(organization: organization, cost_category: category, name: '伐採 人工', unit: '人日',
                     unit_price: 28_000)

    expect { category.destroy }.not_to change(described_class, :count)
    expect(category.errors).to be_present
  end

  it '項目が使っていない区分は削除できる' do
    category = described_class.create!(organization: organization, name: '伐採費')

    expect { category.destroy }.to change(described_class, :count).by(-1)
  end
end
