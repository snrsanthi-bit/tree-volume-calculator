# frozen_string_literal: true

class PolygonIntersectionChecker
  def initialize(points)
    @points = points
  end

  def self_intersecting?
    edges = polygon_edges

    edges.each_with_index.any? do |first_edge, first_index|
      edges.each_with_index.any? do |second_edge, second_index|
        next false unless edges_can_intersect?(first_index, second_index, edges.size)

        segments_intersect?(*first_edge, *second_edge)
      end
    end
  end

  private

  def polygon_edges
    @points.each_index.map do |index|
      [
        @points[index],
        @points[(index + 1) % @points.size]
      ]
    end
  end

  def edges_can_intersect?(first_index, second_index, edge_count)
    return false if second_index <= first_index
    return false if second_index == first_index + 1
    return false if first_index.zero? && second_index == edge_count - 1

    true
  end

  def segments_intersect?(first_start, first_end, second_start, second_end)
    first_side = cross(first_start, first_end, second_start) *
                 cross(first_start, first_end, second_end)
    second_side = cross(second_start, second_end, first_start) *
                  cross(second_start, second_end, first_end)

    first_side.negative? && second_side.negative?
  end

  def cross(first_point, second_point, third_point)
    ((second_point[0] - first_point[0]) * (third_point[1] - first_point[1])) -
      ((second_point[1] - first_point[1]) * (third_point[0] - first_point[0]))
  end
end
