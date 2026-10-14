# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :users
  has_many :work_locations

  validates :name, presence: true
end
