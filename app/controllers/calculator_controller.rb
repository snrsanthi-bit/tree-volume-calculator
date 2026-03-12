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
    @volume = 0.5 * Math::PI * (dbh / 100)**2 * height

    render :index
  end

  def area
    @area = params[:area].to_f

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "area-result",
          partial: "calculator/area_result",
          locals: { area: @area }
        )
      end
    end
  end
end
