# frozen_string_literal: true

require 'rails_helper'

# Devise が出すお知らせが、辞書の不足で "Translation missing" と出ないこと。
# お知らせは画面によって出る・出ないが違うので、画面の本文ではなく、flash と辞書を直接確かめる。
RSpec.describe 'Devise のメッセージ', type: :request do
  let(:password) { 'password123' }
  let(:user) do
    User.create!(
      name: '管理者太郎', email: 'admin@example.com', role: :admin, organization: Organization.create!(name: '林業会社A'),
      password: password, password_confirmation: password
    )
  end

  it 'ログインしたとき、お知らせが日本語になる' do
    post user_session_path, params: { user: { email: user.email, password: password } }

    expect(flash[:notice]).to include('ログイン')
  end

  it 'ログアウトしたとき、お知らせが日本語になる' do
    sign_in user
    delete destroy_user_session_path

    expect(flash[:notice]).to include('ログアウト')
  end

  # ログインの失敗・ログインしていない・時間切れなど、画面に出る可能性のあるメッセージ
  %w[
    devise.failure.invalid devise.failure.unauthenticated devise.failure.timeout
    devise.failure.not_found_in_database devise.failure.locked
    devise.sessions.signed_in devise.sessions.signed_out devise.sessions.already_signed_out
    devise.passwords.send_instructions devise.passwords.updated
  ].each do |key|
    it "辞書に #{key} がある" do
      message = I18n.t(key, authentication_keys: 'メールアドレス', raise: true)

      expect(message).to match(/\p{Hiragana}|\p{Katakana}|\p{Han}/)
    end
  end
end
