# frozen_string_literal: true

class CalculatorController < ApplicationController
  def index
    @volume = params[:volume]&.to_f
    @dbh = params[:dbh]
    @height = params[:height]

    @area = params[:area]&.to_f
    @a = params[:a]
    @b = params[:b]
    @c = params[:c]
  end

  def calculate
    dbh = params[:dbh].to_f
    height = params[:height].to_f

    # Calculate the volume (example formula)
    @volume = TreeVolume.calculate(dbh: dbh, height: height)

    render :index

    rescue ArgumentError => e
    @error = I18n.t("calculator.errors.#{e.message}")
    @volume = nil


    render :index
  end

  def area
    if params[:error]
      @error = I18n.t("calculator.errors.#{params[:error]}")
            
      else
        
        @area =params[:area].to_f
        
      end

    respond_to do |format|
      format.turbo_stream do
        if @error
          render turbo_stream: turbo_stream.update(
            'area-result',
            partial: 'calculator/error',
            locals: { error: @error }
          )
        else
          render turbo_stream:turbo_stream.update(
            "area-result",
            partial:"calculator/area_result",
            locals: { area: @area }
          )
        end
      end
    end
  end
end
