# frozen_string_literal: true

# 金額を、重み（区分ごとの直接費など）の比に応じて配る。配った合計は、必ず元の金額と一致する。
#
# unit の倍数で配る（売価が1,000円単位なら、区分ごとの金額も1,000円単位になる）。
# 端数は、あまりの大きい順に、1単位ずつ足す（最大剰余法）。あまりが同じなら、重みの大きいほうを先にする。
# 重みが0の区分は0円になる。重みがすべて0（明細がない）なら、すべて0円。
#
#   PriceAllocator.call(total: 100, weights: [1, 1, 1], unit: 1) # => [34, 33, 33]
class PriceAllocator
  def self.call(total:, weights:, unit: 1)
    new(total, weights, unit).call
  end

  def initialize(total, weights, unit)
    @total = Integer(total)
    @weights = weights.map { |weight| Integer(weight) }
    @unit = usable_unit(unit)
    raise ArgumentError, :negative_total if @total.negative?
    raise ArgumentError, :negative_weight if @weights.any?(&:negative?)
  end

  def call
    return Array.new(@weights.size, 0) if @total.zero? || @weights.sum.zero?

    shares = shares_in_units
    counts = shares.map(&:floor)
    leftover_order(shares, counts).first(units - counts.sum).each { |index| counts[index] += 1 }
    counts.map { |count| count * @unit }
  end

  private

  def units
    @total / @unit
  end

  # 各区分の取り分（単位の数、端数つき）
  def shares_in_units
    weight_sum = @weights.sum

    @weights.map { |weight| Rational(units * weight, weight_sum) }
  end

  # 端数を足す順番。あまりが大きい順、同じなら重みが大きい順、さらに同じなら並びの早い順
  def leftover_order(shares, counts)
    @weights.each_index.sort_by { |index| [counts[index] - shares[index], -@weights[index], index] }
  end

  # 合計が単位の倍数でなければ、1円単位で配る
  def usable_unit(unit)
    unit = Integer(unit)

    unit.positive? && (@total % unit).zero? ? unit : 1
  end
end
