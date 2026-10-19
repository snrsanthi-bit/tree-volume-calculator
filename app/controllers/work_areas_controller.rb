# frozen_string_literal: true

class WorkAreasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_work_area, only: %i[show edit]

  def index
    work_areas = current_user.organization.work_areas

    render json: work_areas
  end

  def show; end

  def edit; end

  def create
    work_area = current_user.organization.work_areas.new(work_area_params)

    if work_area.save
      redirect_to work_area_path(work_area), notice: t('.success')
    else
      redirect_to area_path, alert: t('.failure')
    end
  end

  private

  def set_work_area
    @work_area = current_user.organization.work_areas.find(params.expect(:id))
  end

  def work_area_params
    params.expect(
      work_area: [
        :name,
        { coordinates: [%i[lat lng]] }
      ]
    )
  end
end
