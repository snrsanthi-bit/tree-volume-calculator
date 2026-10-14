# frozen_string_literal: true

class AddDeactivatedAtToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :deactivated_at, :datetime
  end
end
