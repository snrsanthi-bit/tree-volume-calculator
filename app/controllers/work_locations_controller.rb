# frozen_string_literal: true

class WorkLocationsController < ApplicationController
  before_action :authenticate_user!

  def create
    work_location = current_user.organization.work_locations.new(work_location_params)

    if work_location.save
      redirect_to root_path, notice: t('.success')
    else
      redirect_to root_path, alert: t('.failure')
    end
  end

  private

  def work_location_params
    params.expect(work_location: %i[name latitude longitude])
  end
end
