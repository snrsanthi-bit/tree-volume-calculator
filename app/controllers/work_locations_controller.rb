# frozen_string_literal: true

class WorkLocationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @work_locations = current_user.organization.work_locations
  end

  def show
    @work_location = current_user.organization.work_locations.find(params.expect(:id))
  end

  def create
    work_location = current_user.organization.work_locations.new(work_location_params)

    head :forbidden and return unless current_user.admin?

    if work_location.save
      redirect_to root_path, notice: t('.success')
    else
      redirect_to root_path, alert: t('.failure')
    end
  end

  def update
    work_location = current_user.organization.work_locations.find(params.expect(:id))

    head :forbidden and return unless current_user.admin?

    if work_location.update(work_location_params)
      redirect_to work_location_path(work_location), notice: t('.success')
    else
      redirect_to work_location_path(work_location), alert: t('.failure')
    end
  end

  private

  def work_location_params
    params.expect(work_location: %i[name latitude longitude])
  end
end
