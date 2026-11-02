# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConsumptionTax do
  def tax(amount, mode, rate = 10)
    described_class.call(amount: amount, rate: rate, mode: mode)
  end

  it '端数がなければ、どの処理でも同じ' do
    expect(tax(929_000, :floor)).to eq(92_900)
    expect(tax(929_000, :ceil)).to eq(92_900)
    expect(tax(929_000, :round)).to eq(92_900)
  end

  it '切り捨て・切り上げ・四捨五入で、端数の扱いが変わる' do
    expect(tax(1_005, :floor)).to eq(100)
    expect(tax(1_005, :ceil)).to eq(101)
    expect(tax(1_005, :round)).to eq(101)
    expect(tax(1_004, :round)).to eq(100)
  end

  it '小数の税率でも、誤差なく計算する（BigDecimal）' do
    expect(tax(1_000, :floor, BigDecimal('8.5'))).to eq(85)
    expect(tax(999, :ceil, BigDecimal('8'))).to eq(80)
  end

  it '税率0%や金額0円なら0円' do
    expect(tax(1_000, :floor, 0)).to eq(0)
    expect(tax(0, :ceil)).to eq(0)
  end

  it '知らない処理はエラー' do
    expect { tax(1_000, :unknown) }.to raise_error(ArgumentError)
  end
end
