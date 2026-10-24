# frozen_string_literal: true

class WorkAreasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_work_area, only: %i[show edit update]

  def index
    @work_areas = current_user.organization.work_areas

    respond_to do |format|
      format.html
      format.json { render json: @work_areas }
    end
  end

  def show; end

  def new
    @work_area = current_user.organization.work_areas.new
  end

  def edit; end

  def create
    @work_area = current_user.organization.work_areas.new(work_area_params)

    if @work_area.save
      redirect_to work_area_path(@work_area), notice: t('.success')
    else
      flash.now[:alert] = "保存に失敗しました: #{@work_area.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @work_area.update(work_area_params)
      redirect_to work_area_path(@work_area), notice: t('.success')
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_work_area
    @work_area = current_user.organization.work_areas.find(params.expect(:id))
  end

  def work_area_params
    params.expect(work_area: [:name]).to_h
          .symbolize_keys
          .merge(
            coordinates: parsed_coordinates,
            survey_data: parsed_survey_data
          )
  rescue JSON::ParserError, TypeError
    params.expect(work_area: [:name]).to_h
          .symbolize_keys
          .merge(coordinates: [], survey_data: {})
  end

  def parsed_coordinates
    raw_coordinates = params.dig(:work_area, :coordinates)

    case raw_coordinates
    when String
      JSON.parse(raw_coordinates)
    when Array
      raw_coordinates
    else
      []
    end
  end

  def parsed_survey_data
    raw = params.dig(:work_area, :survey_data)

    return raw.to_unsafe_h if raw.is_a?(ActionController::Parameters)
    return raw if raw.is_a?(Hash)
    return parse_survey_data_json(raw) if raw.is_a?(String)

    {}
  end

  def parse_survey_data_json(raw_survey_data)
    parsed = JSON.parse(raw_survey_data)
    parsed.is_a?(Hash) ? parsed : {}
  end
end
