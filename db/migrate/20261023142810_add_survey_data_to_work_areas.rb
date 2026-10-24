# frozen_string_literal: true

class AddSurveyDataToWorkAreas < ActiveRecord::Migration[8.1]
  def change
    add_column :work_areas, :survey_data, :jsonb, default: {}
  end
end
