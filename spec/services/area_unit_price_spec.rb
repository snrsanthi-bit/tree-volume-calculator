# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AreaUnitPrice do
  def unit_price(mode, unit, price: 929_000, area: 8420)
    described_class.call(price: price, area: BigDecimal(area.to_s), unit: BigDecimal(unit.to_s), mode: mode)
  end

  # 929,000円 ÷ 8,420㎡ = 110.3325...円
  it '端数の単位と処理で、㎡単価を丸める' do
    expect(unit_price(:ceil, 1)).to eq(111)
    expect(unit_price(:floor, 1)).to eq(110)
    expect(unit_price(:round, 1)).to eq(110)
    expect(unit_price(:ceil, '0.1')).to eq(BigDecimal('110.4'))
    expect(unit_price(:round, '0.1')).to eq(BigDecimal('110.3'))
    expect(unit_price(:floor, 10)).to eq(110)
    expect(unit_price(:ceil, 10)).to eq(120)
  end

  it '四捨五入は、ちょうど半分のとき切り上げる' do
    expect(unit_price(:round, 1, price: 1_005, area: 10)).to eq(101)
  end

  it '金額が0円なら、㎡単価も0円' do
    expect(unit_price(:ceil, 1, price: 0)).to eq(0)
  end

  it '面積が0以下、単位が0以下、知らない処理は受け付けない' do
    expect { unit_price(:ceil, 1, area: 0) }.to raise_error(ArgumentError)
    expect { unit_price(:ceil, 0) }.to raise_error(ArgumentError)
    expect { unit_price(:unknown, 1) }.to raise_error(ArgumentError)
  end
end
