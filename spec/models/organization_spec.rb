# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe 'バリデーション' do
    it '組織名があれば有効' do
      organization = described_class.new(name: '林業会社A')
      expect(organization).to be_valid
    end

    it '組織名がなければ無効' do
      organization = described_class.new(name: nil)
      expect(organization).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it '複数のユーザーを持てる' do
      association = described_class.reflect_on_association(:users)

      expect(association.macro).to eq(:has_many)
    end

    it '複数の作業地点を持てる' do
      association = described_class.reflect_on_association(:work_locations)

      expect(association.macro).to eq(:has_many)
    end
  end
end
