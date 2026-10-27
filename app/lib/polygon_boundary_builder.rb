# frozen_string_literal: true

class PolygonBoundaryBuilder
  def initialize(points)
    @points = points
  end

  def build
    return @points if @points.size < 3

    center_x = @points.sum { |point| point[0] } / @points.size.to_f
    center_y = @points.sum { |point| point[1] } / @points.size.to_f

    @points.sort_by do |point|
      Math.atan2(point[1] - center_y, point[0] - center_x)
    end
  end
end
