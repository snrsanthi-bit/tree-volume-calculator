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

  describe '利用状態' do
    it '作成直後は利用停止になっていない' do
      organization = described_class.new(name: '林業会社A')

      expect(organization.deactivated_at).to be_nil
    end

    it '利用停止日時を設定できる' do
      organization = described_class.new(
        name: '林業会社A',
        deactivated_at: Time.current
      )

      expect(organization.deactivated_at).to be_present
    end

    it '利用停止日時が設定されていれば利用停止状態になる' do
      organization = described_class.new(
        name: '林業会社A',
        deactivated_at: Time.current
      )

      expect(organization.deactivated?).to be true
    end
  end
end
