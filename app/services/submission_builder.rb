# frozen_string_literal: true

# 見積から、元請けに出す内容（Submission）を組み立てる。画面や書式には依存しない。
#
# - 項目別の内訳: 区分ごとの直接費の割合で、金額（税抜）を配る。合計は必ず金額と一致する。
# - ㎡単価: 金額 ÷ 面積を、端数の単位と処理（見積にコピーされたもの）で丸める。
class SubmissionBuilder
  TIME_ZONE = 'Asia/Tokyo'
  AREA_PRICE_ROW_NAME = '作業費'
  NO_LINES_MESSAGE = 'この見積には明細がありません。明細を足すと、提出書を作れます。'
  NO_AREA_MESSAGE = '面積が入っていないため、㎡単価の形式では出せません。見積の編集で面積を入れるか、項目別の内訳を選んでください。'

  def self.call(estimate)
    new(estimate).call
  end

  def initialize(estimate)
    @estimate = estimate
  end

  def call
    @result = @estimate.calculation
    area_price = build_area_price

    Submission.new(
      **header, **amounts, issuer:, note: setting.submission_note, format: @estimate.submission_format.to_sym,
                           rows: rows(area_price), area_price:, problem:
    )
  end

  private

  # 金額（税抜）と消費税と税込。消費税は、金額全体にかけて1回だけ計算する（明細ごとには計算しない）
  def amounts
    tax = @estimate.tax_for(@result.price)

    { price: @result.price, tax_rate: @estimate.tax_rate, tax:, total: @result.price + tax }
  end

  def header
    {
      number_label: @estimate.number_label, site_name: @estimate.name, client_name: @estimate.client_name,
      issued_on: @estimate.created_at.in_time_zone(TIME_ZONE).to_date
    }
  end

  # 社名が空なら、組織の名前を使う
  def issuer
    Submission::Issuer.new(
      name: setting.issuer_name.presence || @estimate.organization.name,
      address: setting.issuer_address, phone: setting.issuer_phone
    )
  end

  def setting
    @setting ||= EstimateSetting.for(@estimate.organization)
  end

  def problem
    return NO_LINES_MESSAGE if @result.category_direct.empty?

    NO_AREA_MESSAGE if @estimate.submission_format_area_price? && @estimate.area.nil?
  end

  def rows(area_price)
    return [] if problem

    area_price ? area_price_rows(area_price) : breakdown_rows
  end

  # 区分の並び順で、直接費の割合に応じて金額を配る。0円になった区分は載せない
  def breakdown_rows
    categories = CostCategory.where(id: @result.category_direct.keys).ordered.to_a
    weights = categories.map { |category| @result.category_direct[category.id] }
    amounts = PriceAllocator.call(total: @result.price, weights:, unit: @estimate.rounding_unit)

    categories.zip(amounts).reject { |_, amount| amount.zero? }
              .map { |category, amount| Submission::Row.new(name: category.name, amount:) }
  end

  def area_price_rows(area_price)
    [Submission::Row.new(name: AREA_PRICE_ROW_NAME, quantity: area_price.area, unit: '㎡',
                         unit_price: area_price.unit_price, amount: @result.price)]
  end

  def build_area_price
    return unless @estimate.submission_format_area_price? && @estimate.area

    unit_price = AreaUnitPrice.call(
      price: @result.price, area: @estimate.area, unit: @estimate.area_price_rounding_unit,
      mode: @estimate.rounding_mode.to_sym
    )
    product = (unit_price.to_r * @estimate.area.to_r).round(half: :up)

    Submission::AreaPrice.new(area: @estimate.area, unit_price:, product:, difference: @result.price - product)
  end
end
