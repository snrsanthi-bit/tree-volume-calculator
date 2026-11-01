# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :work_areas, dependent: :restrict_with_error
  has_one :estimate_setting, dependent: :destroy
  has_many :cost_categories, dependent: :restrict_with_error
  has_many :cost_items, dependent: :restrict_with_error
  has_many :estimates, dependent: :restrict_with_error

  validates :name, presence: true

  def deactivated?
    deactivated_at.present?
  end
end
