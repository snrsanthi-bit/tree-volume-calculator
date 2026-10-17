# frozen_string_literal: true

class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :integer, default: 2, null: false
  end

  def down
    remove_column :users, :role
  end
end
