# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Estimate do
  include EstimateSampleHelpers

  let(:organization) { Organization.create!(name: '林業会社A') }

  describe '.build_for' do
    it '会社の今の設定を、見積にコピーする' do
      EstimateSetting.for(organization).update!(
        overhead_rate: 8, margin_rate: 25, margin_basis: :cost, rounding_unit: 100, rounding_mode: :floor
      )

      estimate = described_class.build_for(organization, name: '現場A')

      expect(estimate).to have_attributes(
        organization: organization, name: '現場A', overhead_rate: 8, margin_rate: 25, margin_basis: 'cost',
        rounding_unit: 100, rounding_mode: 'floor'
      )
    end

    it '設定がない会社は、初期値で設定を作って、コピーする' do
      estimate = nil

      expect { estimate = described_class.build_for(organization, name: '現場A') }
        .to change(EstimateSetting, :count).by(1)
      expect(estimate).to have_attributes(margin_rate: 30, margin_basis: 'sales', rounding_unit: 1000)
    end
  end

  describe 'バリデーション' do
    def build_estimate(**attributes)
      described_class.build_for(organization, { name: '現場A' }.merge(attributes))
    end

    it '現場名が必要で、50文字まで' do
      expect(build_estimate(name: '')).not_to be_valid
      expect(build_estimate(name: 'あ' * 51)).not_to be_valid
      expect(build_estimate(name: 'あ' * 50)).to be_valid
    end

    it '面積は空でもよいが、入れるなら0より大きい値' do
      expect(build_estimate(area: nil)).to be_valid
      expect(build_estimate(area: 0)).not_to be_valid
      expect(build_estimate(area: -1)).not_to be_valid
    end

    it '面積に、全角数字やカンマが入っていても受け付ける' do
      estimate = build_estimate(area: '８，４２０．５')

      expect(estimate).to be_valid
      expect(estimate.area).to eq(BigDecimal('8420.5'))
    end
  end

  describe '#calculation' do
    it '明細と、コピーした設定から、金額を計算する' do
      result = create_sample_estimate(organization).calculation

      expect(result).to have_attributes(direct: 619_000, overhead: 30_950, cost: 649_950, price: 929_000)
      expect(result.target_met).to be true
    end

    it '会社の設定を変えても、作成済みの見積の売価は変わらない' do
      estimate = create_sample_estimate(organization)

      EstimateSetting.for(organization).update!(margin_rate: 50, rounding_mode: :floor)

      expect(estimate.reload.calculation.price).to eq(929_000)
    end

    it '明細が0件なら、すべて0円' do
      estimate = described_class.build_for(organization, name: '現場A')
      estimate.save!

      expect(estimate.calculation).to have_attributes(direct: 0, cost: 0, price: 0)
    end
  end

  it '見積を削除すると、明細も消える' do
    estimate = create_sample_estimate(organization)

    expect { estimate.destroy }.to change(EstimateLine, :count).by(-5)
  end
end
