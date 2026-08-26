require "rails_helper"

RSpec.describe TreeVolume do
  describe ".calculate" do
    it "直径と高さから材積を計算できる" do
      volume = described_class.calculate(dbh: 30, height: 4)

      expected_volume = 0.5 * Math::PI * (30 / 100.0) ** 2 * 4

      expect(volume).to eq(expected_volume)
    end

    it "計算可能な小さい数字(0.001㎥付近)" do
      volume = described_class.calculate(dbh: 2.52, height: 1)

      expect(volume).to be_within(0.0001).of(0.001)
    end

    it "0㎥付近" do
      volume = described_class.calculate(dbh: 0, height: 1)

      expect(volume).to eq(0)
    end

    it "大きい数字(39,269,908.17 m³付近)" do
      volume = described_class.calculate(dbh: 10_000, height: 10_000)

      expect(volume).to be_finite
    end
  end
end
