# frozen_string_literal: true

require 'rails_helper'

# ログイン画面と、画面の上に出るお知らせ
RSpec.describe 'ログイン画面とお知らせ', type: :request do
  let(:password) { 'password123' }
  let(:user) do
    User.create!(
      name: '管理者太郎', email: 'admin@example.com', role: :admin, organization: Organization.create!(name: '林業会社A'),
      password: password, password_confirmation: password
    )
  end

  it 'ログイン画面に、メールアドレス・パスワード・ログインボタンがある' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('メールアドレス', 'パスワード', 'name="user[email]"', 'name="user[password]"')
  end

  it 'パスワードが違うと、画面にエラーが出る' do
    post user_session_path, params: { user: { email: user.email, password: 'wrong-password' } }

    expect(response.body).to include('パスワードが違います')
    expect(response.body).not_to match(/translation missing/i)
  end

  it 'ログインすると、移動先の画面にお知らせが出る' do
    post user_session_path, params: { user: { email: user.email, password: password } }
    follow_redirect!

    expect(response.body).to include('ログインしました')
  end

  it 'ログアウトすると、移動先の画面にお知らせが出る' do
    sign_in user
    delete destroy_user_session_path
    follow_redirect!

    expect(response.body).to include('ログアウトしました')
  end

  it '画面側でも出していたお知らせは、二重に出ない' do
    sign_in user
    post admin_cost_categories_path, params: { cost_category: { name: '伐採費' } }
    follow_redirect!

    expect(response.body.scan('区分を追加しました').size).to eq(1)
  end
end
