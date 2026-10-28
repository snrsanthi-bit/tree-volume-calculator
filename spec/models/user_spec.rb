# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    let(:organization) { Organization.create!(name: '林業会社A') }

    def build_user(name: '山田太郎')
      described_class.new(
        name: name,
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization
      )
    end

    it '名前とメールアドレス、パスワード、組織があれば有効' do
      expect(build_user).to be_valid
    end

    it '名前が空なら無効' do
      expect(build_user(name: '')).not_to be_valid
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

  describe '招待' do
    let(:organization) { Organization.create!(name: '林業会社A') }
    let(:user) do
      described_class.create!(name: '新人', email: 'new@example.com', organization: organization,
                              password: described_class.unusable_password)
    end

    it '招待URLの有効期間は7日' do
      expect(described_class.reset_password_within).to eq(7.days)
    end

    it '招待トークンを再発行すると、前のトークンは使えなくなる' do
      old_token = user.issue_invitation_token!
      new_token = user.issue_invitation_token!

      expect(described_class.with_reset_password_token(old_token)).to be_nil
      expect(described_class.with_reset_password_token(new_token)).to eq(user)
    end

    it '誰も知らないパスワードは毎回異なる' do
      expect(described_class.unusable_password).not_to eq(described_class.unusable_password)
    end
  end
end
