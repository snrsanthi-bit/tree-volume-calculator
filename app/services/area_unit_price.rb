# frozen_string_literal: true

# 売価（円）を面積（㎡）で割った㎡単価を、端数の単位と処理で丸めて返す。
#
#   AreaUnitPrice.call(price: 929_000, area: 8420, unit: BigDecimal('0.1'), mode: :round)
#   # => 110.3（BigDecimal）
#
# 割り算は Rational（分数）で行い、誤差を出さない。
class AreaUnitPrice
  MODES = %i[ceil round floor].freeze

  def self.call(price:, area:, unit:, mode:)
    new(price, area, unit, mode).call
  end

  def initialize(price, area, unit, mode)
    @price = Rational(price)
    @area = area.to_r
    @unit = unit.to_r
    @mode = mode
    raise ArgumentError, :area unless @area.positive?
    raise ArgumentError, :unit unless @unit.positive?
    raise ArgumentError, :mode unless MODES.include?(mode)
  end

  def call
    BigDecimal(count * @unit, 20)
  end

  private

  # 端数の単位がいくつ入るか
  def count
    quotient = @price / @area / @unit

    @mode == :round ? quotient.round(half: :up) : quotient.public_send(@mode)
  end
end
