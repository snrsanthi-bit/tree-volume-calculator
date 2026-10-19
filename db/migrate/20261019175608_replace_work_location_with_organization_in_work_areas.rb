# frozen_string_literal: true

class ReplaceWorkLocationWithOrganizationInWorkAreas < ActiveRecord::Migration[8.1]
  def change
    remove_reference :work_areas, :work_location, foreign_key: true

    add_reference :work_areas, :organization, null: false, foreign_key: true

    drop_table :work_locations do |t|
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.bigint :organization_id, null: false
      t.timestamps
      t.index :organization_id
    end
  end
end
