# frozen_string_literal: true

class TreeVolume
  def self.calculate(dbh:, height:)
    0.5 * Math::PI * ((dbh / 100.0)**2) * height
  end
end
