# frozen_string_literal: true

# 見積の金額を計算する。画面やDBには依存しない（明細と設定を渡すと、金額を返すだけ）。
# 金額の計算はすべて Rational（分数）で行い、誤差を出さない。円は整数で返す。
#
#   result = EstimateCalculator.call(
#     lines: [EstimateCalculator::Line.new(category_id, 6, 28_000)],
#     settings: EstimateCalculator::Settings.new(
#       overhead_rate: 5, margin_rate: 30, margin_basis: :sales, rounding_unit: 1000, rounding_mode: :ceil
#     )
#   )
#   result.price # => 売価（円）
class EstimateCalculator
  # 明細。quantity は数量、unit_price は単価（円）。
  Line = Struct.new(:category_id, :quantity, :unit_price)

  # 設定。rate はパーセント（5% なら 5）。
  #   margin_basis   : :sales（売価に対する利益率）/ :cost（原価に上乗せ）
  #   rounding_unit  : 売価の端数の単位（円）。1 / 10 / 100 / 1000 など、正の整数
  #   rounding_mode  : :ceil（切り上げ）/ :round（四捨五入）/ :floor（切り捨て）
  Settings = Struct.new(:overhead_rate, :margin_rate, :margin_basis, :rounding_unit, :rounding_mode,
                        keyword_init: true)

  # margin_on_sales / margin_on_cost はパーセント（Float、表示用）。
  # target_met は、丸めたあとの売価でも、目標の利益率を満たしているか。
  Result = Struct.new(:direct, :overhead, :cost, :price, :profit, :margin_on_sales, :margin_on_cost,
                      :target_met, :category_direct, keyword_init: true)

  MARGIN_BASES = %i[sales cost].freeze
  ROUNDING_MODES = %i[ceil round floor].freeze

  def self.call(lines:, settings:)
    new(lines, settings).call
  end

  def initialize(lines, settings)
    @lines = lines
    @settings = settings
    validate!
  end

  def call
    category_direct = sum_by_category
    direct = category_direct.values.sum
    overhead = to_yen(direct * percent(:overhead_rate))
    cost = direct + overhead

    build_result(category_direct, direct, overhead, cost, round_to_unit(raw_price(cost)))
  end

  private

  def build_result(category_direct, direct, overhead, cost, price)
    profit = price - cost

    Result.new(
      direct:, overhead:, cost:, price:, profit:, category_direct:,
      margin_on_sales: ratio(profit, price), margin_on_cost: ratio(profit, cost),
      target_met: target_met?(profit, price, cost)
    )
  end

  # 区分ごとの直接費。明細1行ごとに円未満を四捨五入する（見積書の明細の金額と合計が合うようにするため）。
  def sum_by_category
    @lines.each_with_object({}) do |line, sums|
      amount = to_yen(non_negative(line.quantity) * non_negative(line.unit_price))
      sums[line.category_id] = sums.fetch(line.category_id, 0) + amount
    end
  end

  # 売価に対して利益率 m% : 原価 ÷ (1 − m/100)。原価に上乗せ m% : 原価 × (1 + m/100)。
  def raw_price(cost)
    margin = percent(:margin_rate)

    @settings.margin_basis == :sales ? cost / (1 - margin) : cost * (1 + margin)
  end

  def round_to_unit(value)
    unit = to_rational(@settings.rounding_unit)
    quotient = value / unit
    count = case @settings.rounding_mode
            when :ceil then quotient.ceil
            when :floor then quotient.floor
            else quotient.round(half: :up)
            end

    (count * unit).to_i
  end

  # 丸めた売価が、目標の利益率を満たすか。割り算を避け、掛け算で比べる（誤差を出さない）。
  def target_met?(profit, price, cost)
    base = @settings.margin_basis == :sales ? price : cost

    profit * 100 >= to_rational(@settings.margin_rate) * base
  end

  def ratio(profit, base)
    base.zero? ? 0.0 : profit * 100.0 / base
  end

  def to_yen(value)
    value.round(half: :up)
  end

  def percent(name)
    to_rational(@settings.public_send(name)) / 100
  end

  def non_negative(value)
    number = to_rational(value)
    raise ArgumentError, :negative_value if number.negative?

    number
  end

  # Float は 0.1 のような値が2進数の誤差を持つため、文字列を経由して分数にする。
  def to_rational(value)
    case value
    when nil then raise ArgumentError, :blank_value
    when Float then Rational(value.to_s)
    when String then Rational(value)
    else value.to_r
    end
  end

  def validate!
    raise ArgumentError, :margin_basis unless MARGIN_BASES.include?(@settings.margin_basis)
    raise ArgumentError, :rounding_mode unless ROUNDING_MODES.include?(@settings.rounding_mode)
    raise ArgumentError, :overhead_rate if percent(:overhead_rate).negative?
    raise ArgumentError, :margin_rate unless valid_margin?
    raise ArgumentError, :rounding_unit unless valid_unit?
  end

  # 売価に対する利益率は 100% 未満（100% 以上だと売価が決まらない）。原価に上乗せは 0% 以上。
  def valid_margin?
    margin = percent(:margin_rate)

    !margin.negative? && (@settings.margin_basis == :cost || margin < 1)
  end

  def valid_unit?
    unit = to_rational(@settings.rounding_unit)

    unit.positive? && unit.denominator == 1
  end
end
