# frozen_string_literal: true

# 見積。会社ごと。作成時点の見積の設定をコピーして持つので、あとで会社の設定を変えても金額は変わらない。
# 金額は、明細から EstimateCalculator で計算する（DBには保存しない）。
# 面積は㎡で保存する。手入力が正で、作業範囲の実測地積は取り込める参考値（取り込んだ値は area_from_map で区別する）。
class Estimate < ApplicationRecord
  include PricingTerms

  MAX_AREA = 100_000_000
  SQUARE_METERS_PER_HECTARE = 10_000
  AREA_UNITS = %w[m2 ha].freeze

  # 取り込んだ面積の種類。measured = 実測 / estimated = 地図上の概算（見積の段階では実測できない）
  # 空(nil)は許す（取り込んでいない見積）。取り込むときは、下で必須にする
  enum :area_source_kind, { measured: 0, estimated: 1 }, prefix: true, validate: { allow_nil: true }

  belongs_to :organization
  belongs_to :work_area, optional: true
  has_many :estimate_lines, -> { order(:id) }, dependent: :destroy, inverse_of: :estimate

  normalize_numeric_input :area

  validates :name, presence: true, length: { maximum: 50 }
  validates :area, numericality: { greater_than: 0, less_than_or_equal_to: MAX_AREA }, allow_nil: true
  validates :area, presence: true, if: -> { @area_imported }
  validates :area_source_kind, presence: true, if: -> { @area_imported }
  validate :work_area_belongs_to_organization
  validate :area_unit_must_be_known

  before_save :clear_area_from_map, if: :area_changed?

  # 会社の今の設定をコピーして、新しい見積を作る（まだ保存しない）
  def self.build_for(organization, attributes = {})
    setting = EstimateSetting.for(organization)

    organization.estimates.new(setting.slice(*PricingTerms::FIELDS).merge(attributes))
  end

  # 入力された面積を、㎡にして入れる。unit が 'ha' なら、haとして受け取って㎡にする。
  # 面積の列は小数2桁なので、haは代入する前に㎡へ換算する（先に代入すると 0.842ha が 0.84 に丸まる）
  def assign_area(value, unit)
    @invalid_area_unit = unit.present? && AREA_UNITS.exclude?(unit.to_s)
    hectares = BigDecimal(NumericInput.normalize(value).to_s, exception: false) if unit.to_s == 'ha'

    self.area = hectares ? (hectares * SQUARE_METERS_PER_HECTARE).round(2) : value
  end

  # 作業範囲の地積(㎡)を取り込んで保存する。kind は measured(実測) / estimated(概算)。
  # 手で直すまでは「取り込んだ値」として扱う
  def import_area(work_area, area, kind = :measured)
    @area_imported = true
    self.work_area = work_area
    self.area = area
    self.area_from_map = true
    self.area_source_kind = kind
    save
  ensure
    @area_imported = false
  end

  # 明細と、コピーした設定から、金額を計算する
  def calculation
    lines = estimate_lines.map do |line|
      EstimateCalculator::Line.new(line.cost_category_id, line.quantity, line.unit_price)
    end

    EstimateCalculator.call(lines:, settings: to_calculator_settings)
  end

  private

  # 取り込み以外で面積が変わったら、取り込んだ値ではなくなる
  def clear_area_from_map
    return if @area_imported

    self.area_from_map = false
    self.area_source_kind = nil
  end

  # 単位が ㎡ / ha 以外なら、面積の意味が変わってしまうので保存しない（空は㎡として扱う）
  def area_unit_must_be_known
    errors.add(:area, 'の単位が正しくありません') if @invalid_area_unit
  end

  def work_area_belongs_to_organization
    return if work_area.nil? || work_area.organization_id == organization_id

    errors.add(:work_area, :invalid)
  end
end
