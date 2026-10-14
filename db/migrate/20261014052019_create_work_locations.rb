# frozen_string_literal: true

class CreateWorkLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :work_locations do |t|
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false

      t.timestamps
    end
  end
end
