# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    it '名前とメールアドレス、パスワード、組織があれば有効' do
      organization = Organization.create!(name: '林業会社A')

      user = described_class.new(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization
      )

      expect(user).to be_valid
    end
  end

  describe 'アソシエーション' do
    it '所属する組織を取得できる' do
      organization = Organization.create!(name: '林業会社A')
      user = described_class.create!(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization
      )

      expect(user.organization).to eq(organization)
    end
  end
end
