# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :work_locations, dependent: :restrict_with_error

  validates :name, presence: true

  def deactivated?
    deactivated_at.present?
  end
end
