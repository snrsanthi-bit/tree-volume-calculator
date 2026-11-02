# frozen_string_literal: true

module Admin
  module EstimateSettingsHelper
    MARGIN_BASIS_LABELS = { 'sales' => '売価に対する割合', 'cost' => '原価に上乗せ' }.freeze
    ROUNDING_MODE_LABELS = { 'ceil' => '切り上げ', 'round' => '四捨五入', 'floor' => '切り捨て' }.freeze

    def margin_basis_label(basis)
      MARGIN_BASIS_LABELS.fetch(basis.to_s, basis.to_s)
    end

    def rounding_mode_label(mode)
      ROUNDING_MODE_LABELS.fetch(mode.to_s, mode.to_s)
    end

    def rounding_unit_options
      EstimateSetting::ROUNDING_UNITS.map { |unit| ["#{number_with_delimiter(unit)}円", unit] }
    end

    # 値は、属性の to_s（"0.1" / "1.0" / "10.0"）にそろえる。選択中の項目が正しく選ばれるようにするため
    def area_price_rounding_unit_options
      EstimateSetting::AREA_PRICE_ROUNDING_UNITS.map do |unit|
        ["#{number_with_precision(unit, strip_insignificant_zeros: true)}円", unit.to_s]
      end
    end

    def area_input_unit_options
      [['㎡', 'm2'], ['ha', 'ha']]
    end

    def rounding_mode_options
      EstimateSetting.rounding_modes.keys.map { |mode| [rounding_mode_label(mode), mode] }
    end
  end
end
