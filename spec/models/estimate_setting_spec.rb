# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EstimateSetting do
  let(:organization) { Organization.create!(name: '林業会社A') }

  def build_setting(**attributes)
    described_class.new(organization: organization, **attributes)
  end

  describe '.for' do
    it '設定がなければ初期値で作る（利益率30%・売価に対して・諸経費率0%・1,000円単位の切り上げ）' do
      setting = described_class.for(organization)

      expect(setting).to be_persisted
      expect(setting).to have_attributes(
        overhead_rate: 0, margin_rate: 30, margin_basis: 'sales', rounding_unit: 1000, rounding_mode: 'ceil'
      )
    end

    it '2回呼んでも、会社の設定は1つだけ' do
      expect { 2.times { described_class.for(organization) } }.to change(described_class, :count).by(1)
    end
  end

  describe 'バリデーション' do
    it '初期値のままで有効' do
      expect(build_setting).to be_valid
    end

    it '売価に対する利益率は100%未満（100%以上だと売価が決まらない）' do
      setting = build_setting(margin_basis: :sales, margin_rate: 100)

      expect(setting).not_to be_valid
      expect(setting.errors[:margin_rate]).to be_present
    end

    it '原価に上乗せなら、利益率が100%以上でもよい' do
      expect(build_setting(margin_basis: :cost, margin_rate: 100)).to be_valid
    end

    it '利益率・諸経費率はマイナスにできない' do
      expect(build_setting(margin_rate: -1)).not_to be_valid
      expect(build_setting(overhead_rate: -1)).not_to be_valid
    end

    it '諸経費率は100%を超えられない' do
      expect(build_setting(overhead_rate: 101)).not_to be_valid
    end

    it '端数の単位は 1・10・100・1000 のどれか' do
      expect(build_setting(rounding_unit: 5)).not_to be_valid
      expect(build_setting(rounding_unit: 100)).to be_valid
    end

    it '㎡単価の端数の単位は 0.1・1・10 のどれか（初期値は1）' do
      expect(build_setting.area_price_rounding_unit).to eq(1)
      expect(build_setting(area_price_rounding_unit: '0.1')).to be_valid
      expect(build_setting(area_price_rounding_unit: 10)).to be_valid
      expect(build_setting(area_price_rounding_unit: 5)).not_to be_valid
    end

    it '未知の利益率の定義・端数の処理はエラーにする（例外にしない）' do
      expect(build_setting(margin_basis: 'other')).not_to be_valid
      expect(build_setting(rounding_mode: 'other')).not_to be_valid
    end

    it '会社の設定は1つだけ' do
      described_class.for(organization)

      setting = build_setting

      expect(setting).not_to be_valid
      expect(setting.errors[:organization_id]).to be_present
    end
  end

  describe '数値の入力' do
    it '全角数字・カンマ・空白が入っていても受け付ける' do
      setting = build_setting(margin_rate: '２５．５', overhead_rate: ' ８ ', rounding_unit: '１，０００')

      expect(setting).to be_valid
      expect(setting).to have_attributes(margin_rate: BigDecimal('25.5'), overhead_rate: 8, rounding_unit: 1000)
    end

    it '数値にならない文字列は、エラーにする' do
      expect(build_setting(margin_rate: 'abc')).not_to be_valid
      expect(build_setting(margin_rate: '')).not_to be_valid
    end
  end

  describe '#to_calculator_settings' do
    it '金額計算（EstimateCalculator）にそのまま渡せる' do
      setting = described_class.new(organization: organization, overhead_rate: 5, margin_rate: 30)
      lines = [
        EstimateCalculator::Line.new(1, 6, 28_000), EstimateCalculator::Line.new(2, 4, 24_000),
        EstimateCalculator::Line.new(3, 3, 48_000), EstimateCalculator::Line.new(3, 6, 6_000),
        EstimateCalculator::Line.new(4, 5, 35_000)
      ]

      result = EstimateCalculator.call(lines: lines, settings: setting.to_calculator_settings)

      expect(result.cost).to eq(649_950)
      expect(result.price).to eq(929_000)
    end

    it '利益率の定義と端数の処理を、金額計算が使うシンボルに直す' do
      setting = build_setting(margin_basis: :cost, rounding_mode: :floor)

      expect(setting.to_calculator_settings).to have_attributes(margin_basis: :cost, rounding_mode: :floor)
    end
  end
end
