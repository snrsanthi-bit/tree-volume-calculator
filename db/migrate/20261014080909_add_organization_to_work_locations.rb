class AddOrganizationToWorkLocations < ActiveRecord::Migration[8.1]
  def change
    add_reference :work_locations, :organization, null: false, foreign_key: true
  end
end
