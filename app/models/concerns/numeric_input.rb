# frozen_string_literal: true

# 数値の入力欄に、全角数字・カンマ・空白が入っていても受け付ける（「２８，０００」→「28000」）。
# モデルで normalize_numeric_input :unit_price のように指定すると、その属性に代入された文字列を整える。
# 数値にならない文字列（abc など）は、そのままバリデーションでエラーになる。
module NumericInput
  extend ActiveSupport::Concern

  def self.normalize(value)
    return value unless value.is_a?(String)

    value.tr('０-９', '0-9').tr('．', '.').tr('－−', '-').delete(', 　，').strip
  end

  class_methods do
    def normalize_numeric_input(*attributes)
      attributes.each do |attribute|
        define_method(:"#{attribute}=") { |value| super(NumericInput.normalize(value)) }
      end
    end
  end
end
