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

    radius = dbh / 200.0
    volume = Math::PI * radius**2 * height * 0.5

    redirect_to root_path(
      volume: volume,
      dbh: dbh,
      height: height
    )
  end

  def area
    a = params[:a].to_f
    b = params[:b].to_f
    c = params[:c].to_f

    if a + b <= c || a + c <= b || b + c <= a
      redirect_to root_path, alert: "三角形になりません"
      return
    end


    s = (a + b + c) / 2.0
    @area = Math.sqrt(s * (s - a) * (s - b) * (s - c))

    redirect_to root_path(
      area: @area,
      a: a,
      b: b,
      c: c
    )
  end
end