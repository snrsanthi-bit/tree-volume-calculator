# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    it '名前とメールアドレス、パスワードがあれば有効' do
      user = described_class.new(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )

      expect(user).to be_valid
    end
  end
end
