# frozen_string_literal: true

class WorkArea < ApplicationRecord
  belongs_to :work_location

  validates :name, presence: true
  validates :coordinates, presence: true
end
