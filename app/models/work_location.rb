# frozen_string_literal: true

class WorkLocation < ApplicationRecord
  belongs_to :organization

  validates :name, presence: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
end
