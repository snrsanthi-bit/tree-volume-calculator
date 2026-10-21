# frozen_string_literal: true

require 'rails_helper'

def triangle_area(triangle)
  first, second, third = triangle

  (
    (first[0] * (second[1] - third[1])) +
    (second[0] * (third[1] - first[1])) +
    (third[0] * (first[1] - second[1]))
  ).abs / 2.0
end

RSpec.describe PolygonTriangulator do
  describe '#triangulate' do
    it '三角形の外周から三角形を1つ生成する' do
      points = [
        [0, 0],
        [4, 0],
        [0, 3]
      ]

      triangles = described_class.new(points).triangulate

      expect(triangles.size).to eq(1)
    end

    it '四角形の外周を2つの三角形に分割する' do
      points = [
        [0, 0],
        [4, 0],
        [4, 3],
        [0, 3]
      ]

      triangles = described_class.new(points).triangulate

      expect(triangles.size).to eq(2)
    end

    it '凹多角形を三角形に分割する' do
      points = [
        [0, 0],
        [4, 0],
        [2, 1],
        [4, 4],
        [0, 4]
      ]

      triangles = described_class.new(points).triangulate

      expect(triangles.size).to eq(3)

      total_area = triangles.sum { |triangle| triangle_area(triangle) }

      expect(total_area).to eq(12.0)
    end

    it '外周点が逆順でも正しく分割する' do
      points = [
        [0, 4],
        [4, 4],
        [2, 1],
        [4, 0],
        [0, 0]
      ]

      triangles = described_class.new(points).triangulate

      expect(triangles.size).to eq(3)

      total_area = triangles.sum { |triangle| triangle_area(triangle) }
      expect(total_area).to eq(12.0)
    end

    it '外周点が3点未満なら空配列を返す' do
      points = [
        [0, 0],
        [4, 0]
      ]

      triangles = described_class.new(points).triangulate

      expect(triangles).to eq([])
    end

    it '連続する重複点を除いて三角分割する' do
      points = [
        [0, 0],
        [4, 0],
        [4, 0],
        [4, 3],
        [0, 3]
      ]

      triangles = described_class.new(points).triangulate

      expect(triangles.size).to eq(2)
    end

    it '重複点を除くと3点未満になる場合は空配列を返す' do
      points = [
        [0, 0],
        [0, 0],
        [4, 0]
      ]

      triangles = described_class.new(points).triangulate

      expect(triangles).to eq([])
    end

    it '連続していない重複点がある場合はエラーにする' do
      points = [
        [0, 0],
        [4, 0],
        [4, 3],
        [4, 0],
        [0, 3]
      ]

      expect do
        described_class.new(points).triangulate
      end.to raise_error(ArgumentError, '外周点が重複しています')
    end

    it '自己交差する外周はエラーにする' do
      points = [
        [0, 0],
        [4, 4],
        [0, 4],
        [4, 0]
      ]

      expect do
        described_class.new(points).triangulate
      end.to raise_error(ArgumentError, '外周が自己交差しています')
    end
  end
end
