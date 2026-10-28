# frozen_string_literal: true

class WorkAreasController < ApplicationController
  include RoleAuthorization

  before_action :authenticate_user!
  # 運営(operator)は作業範囲を扱わない / 作業地点・範囲の作成と編集は管理者(admin)だけ
  # （作業者は一覧・詳細の閲覧と、現場で測った実測値の入力ができる）
  before_action { require_roles!(:admin, :worker) }
  before_action(only: %i[new create edit update]) { require_roles!(:admin) }
  before_action :set_work_area, only: %i[show edit update measurements]

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

  # show 画面で入力した実測値だけを保存する。
  # 外周(coordinates)や点・線の構造には触れない（edit の update とは分けている）。
  def measurements
    data = survey_data_with_measurements
    return head :unprocessable_content unless data

    if @work_area.update(survey_data: data)
      render json: { status: 'ok' }
    else
      render json: { errors: @work_area.errors.full_messages }, status: :unprocessable_content
    end
  rescue ArgumentError, TypeError
    head :unprocessable_content
  end

  private

  # 保存済みの survey_data に、送られた実測値だけを反映したものを返す(不正な入力なら nil)
  def survey_data_with_measurements
    raw = params[:measurements]
    data = (@work_area.survey_data || {}).deep_stringify_keys
    return unless raw.respond_to?(:to_unsafe_h) && data['lines'].is_a?(Array)

    apply_measurements(data['lines'], raw.to_unsafe_h)
    data
  end

  def apply_measurements(lines, values)
    lines.each do |line|
      next unless values.key?(line['id'])

      value = values[line['id']]
      line['measured_length'] = value.nil? || value == '' ? nil : Float(value)
    end
  end

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
