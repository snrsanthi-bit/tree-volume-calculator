# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CostItem do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:category) { CostCategory.create!(organization: organization, name: '伐採費') }

  def build_item(**attributes)
    described_class.new(
      { organization: organization, cost_category: category, name: '伐採 人工', unit: '人日', unit_price: 28_000 }
        .merge(attributes)
    )
  end

  it '正しい値なら有効' do
    expect(build_item).to be_valid
  end

  it '項目名と単位が必要' do
    expect(build_item(name: '')).not_to be_valid
    expect(build_item(unit: '')).not_to be_valid
  end

  it '単価は0以上の整数の円' do
    expect(build_item(unit_price: 0)).to be_valid
    expect(build_item(unit_price: -1)).not_to be_valid
    expect(build_item(unit_price: 1.5)).not_to be_valid
    expect(build_item(unit_price: described_class::MAX_UNIT_PRICE + 1)).not_to be_valid
  end

  it '単価に、全角数字やカンマが入っていても受け付ける' do
    item = build_item(unit_price: '２８，０００')

    expect(item).to be_valid
    expect(item.unit_price).to eq(28_000)
    expect(build_item(unit_price: '28,000').unit_price).to eq(28_000)
  end

  it '全角でも、小数や数値でない文字列はエラーにする' do
    expect(build_item(unit_price: '１．５')).not_to be_valid
    expect(build_item(unit_price: 'あいう')).not_to be_valid
  end

  it '他社の区分は指定できない' do
    other_category = CostCategory.create!(organization: other_organization, name: '伐採費')
    item = build_item(cost_category: other_category)

    expect(item).not_to be_valid
    expect(item.errors[:cost_category]).to be_present
  end
end
