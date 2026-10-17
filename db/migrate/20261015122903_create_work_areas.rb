# frozen_string_literal: true

class CreateWorkAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :work_areas do |t|
      t.string :name
      t.jsonb :coordinates
      t.references :work_location, null: false, foreign_key: true

      t.timestamps
    end
  end
end
