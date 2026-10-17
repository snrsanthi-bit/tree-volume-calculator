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

  describe '権限' do
    let(:organization) do
      Organization.create!(name: '林業会社A')
    end

    it '新規ユーザーのデフォルト権限はworkerである' do
      user = described_class.new(
        name: '作業員',
        email: 'worker@example.com',
        password: 'password123',
        organization: organization
      )

      expect(user.role).to eq('worker')
    end

    it 'operator、admin、workerを権限として扱える' do
      expect(described_class.roles.keys).to contain_exactly(
        'operator',
        'admin',
        'worker'
      )
    end

    it '運営ユーザーを判定できる' do
      user = described_class.new(role: :operator)

      expect(user.operator?).to be true
      expect(user.admin?).to be false
      expect(user.worker?).to be false
    end

    it '会社管理者を判定できる' do
      user = described_class.new(role: :admin)

      expect(user.admin?).to be true
      expect(user.operator?).to be false
      expect(user.worker?).to be false
    end

    it '作業員を判定できる' do
      user = described_class.new(role: :worker)

      expect(user.worker?).to be true
      expect(user.admin?).to be false
      expect(user.operator?).to be false
    end
  end
end
