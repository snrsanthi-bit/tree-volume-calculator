# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkArea, type: :model do
  describe '保存' do
    let(:organization) { Organization.create!(name: '林業会社A') }
    let(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end

    let(:coordinates) do
      [
        { 'lat' => 34.3853, 'lng' => 132.4553 },
        { 'lat' => 34.3860, 'lng' => 132.4560 },
        { 'lat' => 34.3865, 'lng' => 132.4550 }
      ]
    end

    it '作業範囲と頂点座標をDBに保存できる' do
      work_area = described_class.create!(
        name: '北側作業範囲',
        coordinates: coordinates,
        work_location: work_location
      )

      saved_work_area = described_class.find(work_area.id)

      expect(saved_work_area.name).to eq('北側作業範囲')
      expect(saved_work_area.coordinates).to eq(coordinates)
      expect(saved_work_area.work_location).to eq(work_location)
    end
  end

  describe 'アソシエーション' do
    it '作業地点に所属する' do
      association = described_class.reflect_on_association(:work_location)

      expect(association.macro).to eq(:belongs_to)
    end
  end
end
