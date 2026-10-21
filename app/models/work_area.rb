# frozen_string_literal: true

class WorkArea < ApplicationRecord
  belongs_to :organization

  validates :name, presence: true
  validates :coordinates, presence: true
  validate :coordinates_must_have_at_least_three_points

  private

  def coordinates_must_have_at_least_three_points
    return unless coordinates.is_a?(Array)
    return if coordinates.size >= 3

    errors.add(:coordinates, 'は3点以上指定してください')
  end
end
