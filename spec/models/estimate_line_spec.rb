# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EstimateLine do
  include EstimateSampleHelpers

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:estimate) { Estimate.build_for(organization, name: '現場A').tap(&:save!) }
  let(:category) { organization.cost_categories.create!(name: '伐採費') }

  def create_item(**attributes)
    category.cost_items.create!(
      { organization: organization, name: '伐採 人工', unit: '人日', unit_price: 28_000 }.merge(attributes)
    )
  end

  def build_line(**attributes)
    estimate.estimate_lines.new(
      { cost_category: category, name: '伐採 人工', unit: '人日', quantity: 1, unit_price: 28_000 }.merge(attributes)
    )
  end

  describe '.from_cost_item' do
    it '単価マスタの項目の、名前・区分・単位・単価をコピーする' do
      line = described_class.from_cost_item(estimate, create_item, '2')

      expect(line).to have_attributes(
        name: '伐採 人工', cost_category: category, unit: '人日', unit_price: 28_000, quantity: 2
      )
      expect(line).to be_valid
    end

    it '数量が空なら1にする' do
      expect(described_class.from_cost_item(estimate, create_item, '').quantity).to eq(1)
    end

    it '単価マスタを変えても、足した明細の名前と単価は変わらない' do
      item = create_item
      line = described_class.from_cost_item(estimate, item, '1').tap(&:save!)

      item.update!(name: '名前を変えた', unit_price: 99_999)

      expect(line.reload).to have_attributes(name: '伐採 人工', unit_price: 28_000)
    end
  end

  describe 'バリデーション' do
    it '正しい値なら有効' do
      expect(build_line).to be_valid
    end

    it '数量・単価はマイナスにできない' do
      expect(build_line(quantity: -1)).not_to be_valid
      expect(build_line(unit_price: -1)).not_to be_valid
      expect(build_line(quantity: 0, unit_price: 0)).to be_valid
    end

    it '数量は小数でもよく、単価は整数の円' do
      expect(build_line(quantity: '0.5')).to be_valid
      expect(build_line(unit_price: '1.5')).not_to be_valid
    end

    it '数量・単価に、全角数字やカンマが入っていても受け付ける' do
      line = build_line(quantity: '１，２．５', unit_price: '２８，０００')

      expect(line).to be_valid
      expect(line).to have_attributes(quantity: BigDecimal('12.5'), unit_price: 28_000)
    end

    it '他社の区分は指定できない' do
      other_category = other_organization.cost_categories.create!(name: '伐採費')

      expect(build_line(cost_category: other_category)).not_to be_valid
    end
  end

  describe '#amount' do
    it '数量 × 単価。円未満は四捨五入する' do
      expect(build_line(quantity: '1.5', unit_price: 333).amount).to eq(500)
      expect(build_line(quantity: 6, unit_price: 28_000).amount).to eq(168_000)
    end

    it '明細の金額の合計が、金額計算の直接費と一致する' do
      sample = create_sample_estimate(organization)

      expect(sample.estimate_lines.sum(&:amount)).to eq(sample.calculation.direct)
    end
  end
end
