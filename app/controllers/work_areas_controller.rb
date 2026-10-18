# frozen_string_literal: true

class WorkAreasController < ApplicationController
  before_action :authenticate_user!

  def index
    work_location = current_user.organization.work_locations.find(
      params.expect(:work_location_id)
    )

    render json: work_location.work_areas
  end

  def show
    @work_location = current_user.organization.work_locations.find(
      params.expect(:work_location_id)
    )
    @work_area = @work_location.work_areas.find(params.expect(:id))
  end

  def edit
    @work_location = current_user.organization.work_locations.find(
      params.expect(:work_location_id)
    )
  end

  def create
    work_location = current_user.organization.work_locations.find(
      params.expect(:work_location_id)
    )

    head :forbidden and return unless current_user.admin?

    work_area = work_location.work_areas.new(work_area_params)

    if work_area.save
      redirect_to work_location_work_area_path(work_location, work_area), notice: t('.success')
    else

      redirect_to edit_work_location_work_areas_path(work_location), alert: t('.failure')
    end
  end

  def update
    work_location = current_user.organization.work_locations.find(
      params.expect(:work_location_id)
    )
    work_area = work_location.work_areas.find(params.expect(:id))

    head :forbidden and return unless current_user.admin?

    update_work_area(work_location, work_area)
  end

  private

  def work_area_params
    params.expect(
      work_area: [
        :name,
        { coordinates: [%i[lat lng]] }
      ]
    )
  end

  def update_work_area(work_location, work_area)
    if work_area.update(work_area_params)
      redirect_to work_location_work_area_path(work_location, work_area),
                  notice: t('.success')
    else
      redirect_to work_location_work_area_path(work_location, work_area),
                  alert: t('.failure')
    end
  end
end
