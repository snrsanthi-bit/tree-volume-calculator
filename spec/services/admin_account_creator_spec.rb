# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminAccountCreator do
  def create_account(overrides = {})
    described_class.call(
      organization_name: '林業会社A', name: '管理者太郎', email: 'admin@example.com', **overrides
    )
  end

  it '会社と管理者アカウントを作り、招待トークンを返す' do
    result = nil

    expect { result = create_account }.to change(Organization, :count).by(1).and change(User, :count).by(1)

    expect(result.user).to be_admin
    expect(result.user.organization.name).to eq('林業会社A')
    expect(User.with_reset_password_token(result.invitation_token)).to eq(result.user)
  end

  it '招待トークンでパスワードを設定でき、設定後はそのパスワードでログインできる' do
    result = create_account

    user = User.reset_password_by_token(
      reset_password_token: result.invitation_token,
      password: 'my-password-123', password_confirmation: 'my-password-123'
    )

    expect(user.errors).to be_empty
    expect(user.valid_password?('my-password-123')).to be true
  end

  it '既にある会社なら会社は増やさず、その会社に管理者を追加する' do
    Organization.create!(name: '林業会社A')

    expect { create_account }.not_to change(Organization, :count)
  end

  it '不正な入力なら何も作らない' do
    expect { create_account(email: 'invalid') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Organization.count).to eq(0)
  end
end
