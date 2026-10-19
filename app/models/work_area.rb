# frozen_string_literal: true

class WorkArea < ApplicationRecord
  belongs_to :organization

  validates :name, presence: true
  validates :coordinates, presence: true
end
