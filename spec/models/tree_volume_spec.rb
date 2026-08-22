require "rails_helper"

RSpec.describe TreeVolume do
  describe ".calculate" do
    it "直径と高さから材積を計算できる" do
      volume = described_class.calculate(dbh: 30, height: 4)

      expected_volume = 0.5 * Math::PI * (30 / 100.0) ** 2 * 4

      expect(volume).to eq(expected_volume)
    end
  end
end
