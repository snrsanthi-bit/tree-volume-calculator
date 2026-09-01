# frozen_string_literal: true

class TreeVolume
  def self.calculate(dbh:, height:)
    raise ArgumentError, :dbh if dbh <= 0
    raise ArgumentError, :height if height <= 0

    0.5 * Math::PI * ((dbh / 100.0)**2) * height
  end
end
