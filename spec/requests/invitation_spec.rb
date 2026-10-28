# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '招待URLからのパスワード設定', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:invited) do
    User.create!(
      name: '新人作業員', email: 'invited@example.com', organization: organization,
      password: User.unusable_password
    )
  end

  def set_password(token, password: 'new-password-123', confirmation: password)
    put user_password_path,
        params: { user: { reset_password_token: token, password: password, password_confirmation: confirmation } }
  end

  it '招待URLを開くとパスワード設定画面が表示される' do
    get edit_user_password_path(reset_password_token: invited.issue_invitation_token!)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('パスワードを設定')
  end

  it 'パスワードを設定するとそのままログインし、トップ画面へ移動する' do
    set_password(invited.issue_invitation_token!)

    expect(response).to redirect_to(root_path)
    expect(invited.reload.valid_password?('new-password-123')).to be true

    get work_areas_path
    expect(response).to have_http_status(:ok)
  end

  it '招待URLは一度しか使えない' do
    token = invited.issue_invitation_token!
    set_password(token)
    delete destroy_user_session_path

    set_password(token, password: 'another-password-456')

    expect(invited.reload.valid_password?('new-password-123')).to be true
    expect(invited.valid_password?('another-password-456')).to be false
  end

  it '再発行すると前の招待URLは使えない' do
    old_token = invited.issue_invitation_token!
    invited.issue_invitation_token!

    set_password(old_token)

    expect(invited.reload.valid_password?('new-password-123')).to be false
  end

  it '有効期間(7日)を過ぎた招待URLは使えない' do
    token = invited.issue_invitation_token!

    travel_to(8.days.from_now) { set_password(token) }

    expect(invited.reload.valid_password?('new-password-123')).to be false
  end

  it '有効期間内(6日後)ならまだ使える' do
    token = invited.issue_invitation_token!

    travel_to(6.days.from_now) { set_password(token) }

    expect(invited.reload.valid_password?('new-password-123')).to be true
  end

  it '確認用パスワードが違うと設定されない' do
    set_password(invited.issue_invitation_token!, confirmation: 'different-password')

    expect(invited.reload.valid_password?('new-password-123')).to be false
  end

  it '設定前は、誰も知らないパスワードなのでログインできない' do
    post user_session_path, params: { user: { email: invited.email, password: 'password123' } }

    get work_areas_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
