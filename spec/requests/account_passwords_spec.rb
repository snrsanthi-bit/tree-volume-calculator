# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'パスワード変更', type: :request do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:user) do
    User.create!(name: '山田太郎', email: 'user@example.com', organization: organization,
                 password: 'password123', password_confirmation: 'password123')
  end

  def change_password(current: 'password123', password: 'new-password-123', confirmation: password)
    patch account_password_path,
          params: { user: { current_password: current, password: password, password_confirmation: confirmation } }
  end

  it '未ログインならログイン画面へ移動する' do
    get edit_account_password_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'ログイン中なら変更画面を開ける' do
    sign_in user

    get edit_account_password_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('現在のパスワード')
  end

  it '現在のパスワードが正しければ変更でき、ログインしたままトップへ移動する' do
    sign_in user

    change_password

    expect(response).to redirect_to(root_path)
    expect(user.reload.valid_password?('new-password-123')).to be true

    get work_areas_path
    expect(response).to have_http_status(:ok)
  end

  it '現在のパスワードが違うと変更されない' do
    sign_in user

    change_password(current: 'wrong-password')

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.valid_password?('password123')).to be true
  end

  it '新しいパスワードが空だと変更されない' do
    sign_in user

    change_password(password: '')

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.valid_password?('password123')).to be true
  end

  it '確認用パスワードが違うと変更されない' do
    sign_in user

    change_password(confirmation: 'different-password')

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.valid_password?('password123')).to be true
  end

  it '未ログインでは変更できない' do
    patch account_password_path, params: { user: { current_password: 'password123', password: 'x' * 10 } }

    expect(response).to redirect_to(new_user_session_path)
    expect(user.reload.valid_password?('password123')).to be true
  end

  it 'メニューに「パスワード変更」が、ログイン中だけ表示される' do
    get root_path
    expect(response.body).not_to include(edit_account_password_path)

    sign_in user
    get root_path
    expect(response.body).to include(edit_account_password_path)
  end
end
