# frozen_string_literal: true

class RemoveWorkLocationFromWorkAreas < ActiveRecord::Migration[8.1]
  def change
    remove_reference :work_areas, :work_location, foreign_key: true
    add_reference :work_areas, :organization, null: false, foreign_key: true
    add_column :work_areas, :latitude, :decimal, precision: 10, scale: 7
    add_column :work_areas, :longitude, :decimal, precision: 10, scale: 7
  end
end
