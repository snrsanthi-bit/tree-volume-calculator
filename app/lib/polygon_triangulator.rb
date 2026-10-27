# frozen_string_literal: true

class PolygonTriangulator
  def initialize(points)
    @points = points.each_with_object([]) do |point, result|
      result << point unless result.last == point
    end

    @points.pop if @points.size > 1 && @points.first == @points.last

    return unless @points.uniq.size != @points.size

    raise ArgumentError, '外周点が重複しています'
  end

  def triangulate
    return [] if @points.size < 3

    raise ArgumentError, '外周が自己交差しています' if PolygonIntersectionChecker.new(@points).self_intersecting?

    vertices = @points.map { |point| { point: point } }
    orientation = signed_area(@points).positive? ? 1 : -1

    triangulate_vertices(vertices, orientation)
  end

  private

  def triangulate_vertices(vertices, orientation)
    triangles = []

    while vertices.size > 3
      triangle = remove_ear(vertices, orientation)
      raise ArgumentError, '三角分割できない多角形です' unless triangle

      triangles << triangle
    end

    triangles << remaining_triangle(vertices)
    triangles
  end

  def signed_area(points)
    points.each_with_index.sum do |point, index|
      following = points[(index + 1) % points.size]

      (point[0] * following[1]) - (following[0] * point[1])
    end / 2.0
  end

  def cross(first_point, second_point, third_point)
    ((second_point[0] - first_point[0]) * (third_point[1] - first_point[1])) -
      ((second_point[1] - first_point[1]) * (third_point[0] - first_point[0]))
  end

  def point_in_triangle?(point, first_point, second_point, third_point)
    first_cross = cross(first_point, second_point, point)
    second_cross = cross(second_point, third_point, point)
    third_cross = cross(third_point, first_point, point)

    all_non_negative = first_cross >= 0 && second_cross >= 0 && third_cross >= 0
    all_non_positive = first_cross <= 0 && second_cross <= 0 && third_cross <= 0

    all_non_negative || all_non_positive
  end

  def remove_ear(vertices, orientation)
    vertices.size.times do |index|
      triangle, ear_vertices = ear_candidate(vertices, index)

      next unless valid_ear?(triangle, vertices, ear_vertices, orientation)

      vertices.delete_at(index)
      return triangle
    end

    nil
  end

  def ear_candidate(vertices, index)
    previous = vertices[(index - 1) % vertices.size]
    current = vertices[index]
    following = vertices[(index + 1) % vertices.size]

    triangle = [
      previous[:point],
      current[:point],
      following[:point]
    ]

    [triangle, [previous, current, following]]
  end

  def valid_ear?(triangle, vertices, ear_vertices, orientation)
    a, b, c = triangle

    return false unless (cross(a, b, c) * orientation).positive?

    vertices.none? do |vertex|
      next false if ear_vertices.include?(vertex)

      point_in_triangle?(vertex[:point], a, b, c)
    end
  end

  def remaining_triangle(vertices)
    vertices.pluck(:point)
  end
end
