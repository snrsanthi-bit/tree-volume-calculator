# frozen_string_literal: true

# 見積の内訳の区分（伐採費・整理費・機械費・処分費など）。会社ごと。
# 単価マスタの項目が使っている区分は削除できない。
class CostCategory < ApplicationRecord
  belongs_to :organization
  has_many :cost_items, -> { order(:id) }, dependent: :restrict_with_error, inverse_of: :cost_category

  validates :name, presence: true, length: { maximum: 30 }, uniqueness: { scope: :organization_id }

  before_create :set_position

  scope :ordered, -> { order(:position, :id) }

  private

  # 新しい区分は、会社の中でいちばん後ろに並べる
  def set_position
    self.position = self.class.where(organization_id: organization_id).maximum(:position).to_i + 1
  end
end
