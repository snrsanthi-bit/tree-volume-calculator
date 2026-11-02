# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PriceAllocator do
  def allocate(total, weights, unit: 1)
    described_class.call(total: total, weights: weights, unit: unit)
  end

  it '重みの比で配り、合計が元の金額と一致する' do
    amounts = allocate(929_000, [168_000, 96_000, 180_000, 175_000], unit: 1000)

    expect(amounts).to eq([252_000, 144_000, 270_000, 263_000])
    expect(amounts.sum).to eq(929_000)
  end

  it '端数は、あまりの大きい順に1単位ずつ足す' do
    expect(allocate(100, [1, 1, 1])).to eq([34, 33, 33])
    expect(allocate(10, [1, 2])).to eq([3, 7])
  end

  it 'あまりが同じなら、重みの大きいほうを先にする。それも同じなら、並びの早いほうを先にする' do
    expect(allocate(1_000, [1, 3], unit: 100)).to eq([200, 800])
    expect(allocate(1, [1, 3, 3, 1])).to eq([0, 1, 0, 0])
  end

  it '単位の倍数で配る。合計が単位の倍数でなければ、1円単位で配る' do
    expect(allocate(10_000, [1, 1, 1], unit: 1000)).to eq([4000, 3000, 3000])
    expect(allocate(1_500, [1, 1], unit: 1000)).to eq([750, 750])
  end

  it '重みが0の区分は0円で、エラーにならない' do
    expect(allocate(929_000, [168_000, 0, 180_000, 175_000], unit: 1000)).to eq([298_000, 0, 320_000, 311_000])
  end

  it '金額が0、または重みがすべて0なら、すべて0円' do
    expect(allocate(0, [1, 2], unit: 1000)).to eq([0, 0])
    expect(allocate(1_000, [0, 0], unit: 1000)).to eq([0, 0])
    expect(allocate(1_000, [])).to eq([])
  end

  it '重みがいくつでも、合計は必ず元の金額と一致する' do
    [[777_000, [1, 2, 3, 4, 5], 1000], [1, [7, 7, 7], 1], [999, [333, 333, 333], 1], [12_345, [5, 0, 11], 1]]
      .each do |total, weights, unit|
        expect(allocate(total, weights, unit: unit).sum).to eq(total)
      end
  end

  it 'マイナスの金額・重みは受け付けない' do
    expect { allocate(-1, [1]) }.to raise_error(ArgumentError)
    expect { allocate(100, [1, -1]) }.to raise_error(ArgumentError)
  end
end
