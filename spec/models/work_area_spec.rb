# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkArea, type: :model do
  describe '保存' do
    let(:organization) { Organization.create!(name: '林業会社A') }

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
        organization: organization
      )

      saved_work_area = described_class.find(work_area.id)

      expect(saved_work_area.name).to eq('北側作業範囲')
      expect(saved_work_area.coordinates).to eq(coordinates)
      expect(saved_work_area.organization).to eq(organization)
    end
  end

  describe 'アソシエーション' do
    it '組織に所属する' do
      association = described_class.reflect_on_association(:organization)

      expect(association.macro).to eq(:belongs_to)
    end
  end
end
