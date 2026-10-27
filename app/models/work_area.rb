# frozen_string_literal: true

class WorkArea < ApplicationRecord
  MAX_SURVEY_POINTS = 500
  MAX_SURVEY_LINES = 2000
  LENGTH_KEYS = %w[estimated_length measured_length].freeze

  belongs_to :organization

  validates :name, presence: true
  validates :coordinates, presence: true
  validate :coordinates_must_have_at_least_three_points
  validate :survey_data_must_be_consistent

  private

  def coordinates_must_have_at_least_three_points
    return unless coordinates.is_a?(Array)
    return if coordinates.size >= 3

    errors.add(:coordinates, 'は3点以上指定してください')
  end

  # survey_data は「点(points)」と「線(lines)」だけを持つ。三角形は保存せず、必要なときに導出する。
  def survey_data_must_be_consistent
    return if survey_data.blank?

    data = survey_data.is_a?(Hash) ? survey_data.deep_stringify_keys : {}
    points = data['points']
    lines = data['lines']

    unless points.is_a?(Array) && lines.is_a?(Array)
      errors.add(:survey_data, 'の形式が正しくありません')
      return
    end

    survey_data_errors(points, lines).each { |message| errors.add(:survey_data, message) }
  end

  def survey_data_errors(points, lines)
    message = survey_size_error(points, lines) || survey_point_error(points) || survey_line_error(points, lines)

    message ? [message] : []
  end

  def survey_size_error(points, lines)
    return unless points.size > MAX_SURVEY_POINTS || lines.size > MAX_SURVEY_LINES

    'の点・線が多すぎます'
  end

  def survey_point_error(points)
    return 'の点の形式が正しくありません' unless points.all? { |point| valid_survey_point?(point) }

    'の点のIDが重複しています' unless points.pluck('id').uniq.size == points.size
  end

  def survey_line_error(points, lines)
    point_ids = points.pluck('id')

    'の線の形式が正しくありません' unless lines.all? { |line| valid_survey_line?(line, point_ids) }
  end

  def valid_survey_point?(point)
    point.is_a?(Hash) &&
      point['id'].is_a?(String) &&
      finite_number?(point['lat']) &&
      finite_number?(point['lng'])
  end

  def valid_survey_line?(line, point_ids)
    line.is_a?(Hash) &&
      line['id'].is_a?(String) &&
      valid_line_endpoints?(line, point_ids) &&
      valid_line_lengths?(line)
  end

  def valid_line_endpoints?(line, point_ids)
    point_ids.include?(line['from']) && point_ids.include?(line['to']) && line['from'] != line['to']
  end

  def valid_line_lengths?(line)
    LENGTH_KEYS.all? { |key| line[key].nil? || positive_number?(line[key]) }
  end

  def finite_number?(value)
    value.is_a?(Numeric) && value.to_f.finite?
  end

  def positive_number?(value)
    finite_number?(value) && value.positive?
  end
end
