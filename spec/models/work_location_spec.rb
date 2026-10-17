# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkLocation, type: :model do
  let(:organization) { Organization.create!(name: '林業会社A') }

  describe 'バリデーション' do
    it '地点名と緯度、経度があれば有効' do
      work_location = described_class.new(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )

      expect(work_location).to be_valid
    end

    it '地点名がなければ無効' do
      work_location = described_class.new(
        name: nil,
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )

      expect(work_location).not_to be_valid
    end

    it '緯度がなければ無効' do
      work_location = described_class.new(
        name: '作業地点A',
        latitude: nil,
        longitude: 132.4553,
        organization: organization
      )

      expect(work_location).not_to be_valid
    end

    it '経度がなければ無効' do
      work_location = described_class.new(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: nil,
        organization: organization
      )

      expect(work_location).not_to be_valid
    end

    it '緯度が有効範囲外なら無効' do
      work_location = described_class.new(
        name: '作業地点A',
        latitude: 91,
        longitude: 132.4553,
        organization: organization
      )

      expect(work_location).not_to be_valid
    end

    it '経度が有効範囲外なら無効' do
      work_location = described_class.new(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 181,
        organization: organization
      )

      expect(work_location).not_to be_valid
    end

    it '緯度の境界値は有効' do
      [90, -90].each do |latitude|
        work_location = described_class.new(
          name: '作業地点A',
          latitude: latitude,
          longitude: 132.4553,
          organization: organization
        )

        expect(work_location).to be_valid
      end
    end

    it '経度の境界値は有効' do
      [180, -180].each do |longitude|
        work_location = described_class.new(
          name: '作業地点A',
          latitude: 34.3853,
          longitude: longitude,
          organization: organization
        )

        expect(work_location).to be_valid
      end
    end

    it '地点情報をDBに保存できる' do
      work_location = described_class.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )

      saved_location = described_class.find(work_location.id)

      expect(saved_location.name).to eq('作業地点A')
      expect(saved_location.latitude).to eq(BigDecimal('34.3853'))
      expect(saved_location.longitude).to eq(BigDecimal('132.4553'))
    end
  end

  describe 'アソシエーション' do
    it '組織に所属する' do
      association = described_class.reflect_on_association(:organization)

      expect(association.macro).to eq(:belongs_to)
    end

    it '複数の作業範囲を持つ' do
      association = described_class.reflect_on_association(:work_areas)

      expect(association).not_to be_nil
      expect(association.macro).to eq(:has_many)
    end
  end
end
