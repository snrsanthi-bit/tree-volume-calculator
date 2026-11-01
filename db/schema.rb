# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_01_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cost_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_cost_categories_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_cost_categories_on_organization_id"
  end

  create_table "cost_items", force: :cascade do |t|
    t.bigint "cost_category_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "unit", null: false
    t.integer "unit_price", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["cost_category_id"], name: "index_cost_items_on_cost_category_id"
    t.index ["organization_id"], name: "index_cost_items_on_organization_id"
  end

  create_table "estimate_settings", force: :cascade do |t|
    t.decimal "area_price_rounding_unit", precision: 4, scale: 1, default: "1.0", null: false
    t.datetime "created_at", null: false
    t.integer "margin_basis", default: 0, null: false
    t.decimal "margin_rate", precision: 5, scale: 2, default: "30.0", null: false
    t.bigint "organization_id", null: false
    t.decimal "overhead_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "rounding_mode", default: 0, null: false
    t.integer "rounding_unit", default: 1000, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_estimate_settings_on_organization_id", unique: true
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.bigint "organization_id", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "work_areas", force: :cascade do |t|
    t.jsonb "coordinates"
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "organization_id", null: false
    t.jsonb "survey_data", default: {}
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_work_areas_on_organization_id"
  end

  add_foreign_key "cost_categories", "organizations"
  add_foreign_key "cost_items", "cost_categories"
  add_foreign_key "cost_items", "organizations"
  add_foreign_key "estimate_settings", "organizations"
  add_foreign_key "users", "organizations"
  add_foreign_key "work_areas", "organizations"
end
