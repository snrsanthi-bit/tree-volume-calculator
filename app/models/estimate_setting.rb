# frozen_string_literal: true

# 会社ごとの見積の設定（利益率・諸経費率・端数）。会社に1つ。
# 項目と検証は PricingTerms にある（見積ごとのコピー Estimate と共通）。
class EstimateSetting < ApplicationRecord
  include PricingTerms

  belongs_to :organization

  # 見積の面積を入力するときの単位の初期値。保存はどちらも㎡（見積ごとにコピーはしない）
  enum :area_input_unit, { m2: 0, ha: 1 }, prefix: true, validate: true, default: :m2

  validates :organization_id, uniqueness: true

  # 会社の設定を返す。まだなければ、初期値で作る。
  def self.for(organization)
    find_or_create_by!(organization: organization)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # 同時に開かれて、先に別のリクエストが作ったとき
    find_by!(organization: organization)
  end
end
