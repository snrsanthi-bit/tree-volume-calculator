# frozen_string_literal: true

# 消費税の計算。税抜の金額と税率から、消費税額（円）を出す。
# 有理数で計算するので、小数の誤差が出ない。端数は mode で決める（ceil=切り上げ / round=四捨五入 / floor=切り捨て）。
class ConsumptionTax
  MODES = %i[ceil round floor].freeze

  def self.call(amount:, rate:, mode:)
    new(amount:, rate:, mode:).call
  end

  def initialize(amount:, rate:, mode:)
    @amount = amount
    @rate = rate
    @mode = mode.to_sym
  end

  def call
    raise ArgumentError, :invalid_mode unless MODES.include?(@mode)

    raw = Rational(@amount) * @rate.to_r / 100
    @mode == :round ? raw.round(half: :up) : raw.public_send(@mode)
  end
end
