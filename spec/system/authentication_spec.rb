# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '認証', type: :system do
  before do
    driven_by :selenium_firefox
  end

  describe 'ログイン' do
    it '登録済みユーザーがログインできる' do
      user = User.create!(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )

      visit new_user_session_path

      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'

      click_button 'Log in'

      expect(page).to have_current_path(root_path)
      expect(page).to have_text(user.name)

      find('button[aria-label="メニュー"]').click

      expect(page).to have_button('ログアウト')
    end
  end

  describe 'ログアウト' do
    it 'ログイン中のユーザーがログアウトできる' do
      user = User.create!(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )

      visit new_user_session_path

      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'

      click_button 'Log in'

      find('button[aria-label="メニュー"]').click
      click_button 'ログアウト'

      expect(page).to have_current_path(root_path)

      find('button[aria-label="メニュー"]').click

      expect(page).to have_link('ログイン')
    end
  end
end
