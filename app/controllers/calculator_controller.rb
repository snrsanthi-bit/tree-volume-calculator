class CalculatorController < ApplicationController
  def index
    @volume = params[:volume]&.to_f
    @dbh = params[:dbh]
    @height = params[:height]
  end

  def calculate
    dbh = params[:dbh].to_f
    height = params[:height].to_f

    radius = dbh / 200.0
    volume = Math::PI * radius**2 * height * 0.5

    redirect_to root_path(
      volume: volume,
      dbh: dbh,
      height: height
    )
  end
end