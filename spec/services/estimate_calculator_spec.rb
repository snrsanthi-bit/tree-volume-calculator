# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EstimateCalculator do
  # 区分のIDは 1: 伐採費 / 2: 整理費 / 3: 機械費 / 4: 処分費 とする
  let(:lines) do
    [
      described_class::Line.new(1, 6, 28_000),
      described_class::Line.new(2, 4, 24_000),
      described_class::Line.new(3, 3, 48_000),
      described_class::Line.new(3, 6, 6_000),
      described_class::Line.new(4, 5, 35_000)
    ]
  end

  def settings(**overrides)
    described_class::Settings.new(
      overhead_rate: 5, margin_rate: 30, margin_basis: :sales, rounding_unit: 1000, rounding_mode: :ceil,
      **overrides
    )
  end

  def calculate(target_lines = lines, **overrides)
    described_class.call(lines: target_lines, settings: settings(**overrides))
  end

  it '直接費・諸経費・原価を計算し、区分ごとの直接費も返す' do
    result = calculate

    expect(result.direct).to eq(619_000)
    expect(result.overhead).to eq(30_950)
    expect(result.cost).to eq(649_950)
    expect(result.category_direct).to eq(1 => 168_000, 2 => 96_000, 3 => 180_000, 4 => 175_000)
  end

  it '売価に対する利益率30%で、1,000円単位に切り上げた売価を返す' do
    result = calculate

    expect(result.price).to eq(929_000)
    expect(result.profit).to eq(279_050)
    expect(result.margin_on_sales).to be_within(0.01).of(30.04)
    expect(result.margin_on_cost).to be_within(0.01).of(42.93)
    expect(result.target_met).to be true
  end

  it '原価に上乗せ30%なら、売価は原価の1.3倍になる' do
    result = calculate(margin_basis: :cost)

    expect(result.price).to eq(845_000)
    expect(result.target_met).to be true
  end

  it '端数の単位が1円なら、割り切れる売価はそのまま返る' do
    result = calculate(rounding_unit: 1)

    expect(result.price).to eq(928_500)
    expect(result.target_met).to be true
  end

  it '切り捨てると売価に対する利益率が30%を下回り、目標を満たさないと分かる' do
    result = calculate(rounding_mode: :floor)

    expect(result.price).to eq(928_000)
    expect(result.margin_on_sales).to be_within(0.01).of(29.96)
    expect(result.target_met).to be false
  end

  it '四捨五入は、ちょうど半分のとき切り上げる' do
    expect(calculate(rounding_mode: :round).price).to eq(929_000)
  end

  it '明細ごとに、円未満を四捨五入する' do
    result = calculate([described_class::Line.new(1, '1.5', 333)], overhead_rate: 0)

    expect(result.direct).to eq(500)
  end

  it '小数の数量を扱える' do
    result = calculate([described_class::Line.new(1, BigDecimal('0.5'), 28_000)], overhead_rate: 0)

    expect(result.direct).to eq(14_000)
  end

  it '諸経費も、円未満を四捨五入する' do
    result = calculate([described_class::Line.new(1, 1, 1_010)])

    expect(result.overhead).to eq(51)
    expect(result.cost).to eq(1_061)
  end

  it '原価に上乗せなら、利益率が100%以上でも計算できる' do
    result = calculate([described_class::Line.new(1, 1, 1_000)], overhead_rate: 0, margin_rate: 100,
                                                                 margin_basis: :cost, rounding_unit: 1)

    expect(result.price).to eq(2_000)
  end

  it '明細が0件なら、すべて0円で、エラーにならない' do
    result = calculate([])

    expect(result.to_h.slice(:direct, :overhead, :cost, :price, :profit)).to eq(
      direct: 0, overhead: 0, cost: 0, price: 0, profit: 0
    )
    expect(result.margin_on_sales).to eq(0.0)
    expect(result.category_direct).to eq({})
    expect(result.target_met).to be true
  end

  {
    '売価に対する利益率が100%' => { margin_rate: 100 },
    '利益率がマイナス' => { margin_rate: -1 },
    '利益率の定義が未知の値' => { margin_basis: :other },
    '端数の処理が未知の値' => { rounding_mode: :other },
    '諸経費率がマイナス' => { overhead_rate: -1 },
    '端数の単位が0' => { rounding_unit: 0 },
    '端数の単位が整数でない' => { rounding_unit: 1.5 }
  }.each do |title, overrides|
    it "#{title}ならエラーにする" do
      expect { calculate(**overrides) }.to raise_error(ArgumentError)
    end
  end

  it '数量や単価がマイナス・未入力ならエラーにする' do
    expect { calculate([described_class::Line.new(1, -1, 1_000)]) }.to raise_error(ArgumentError)
    expect { calculate([described_class::Line.new(1, 1, -1_000)]) }.to raise_error(ArgumentError)
    expect { calculate([described_class::Line.new(1, nil, 1_000)]) }.to raise_error(ArgumentError)
  end
end
