# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '認証', type: :system do
  include ActiveSupport::Testing::TimeHelpers

  before do
    driven_by :selenium_firefox
  end

  def create_user
    User.create!(
      name: '山田太郎',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  def login(user)
    visit new_user_session_path

    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'

    click_button 'Log in'
  end

  describe 'ログイン' do
    it '登録済みユーザーがログインできる' do
      user = create_user

      login(user)

      visit new_user_session_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_text(user.name)

      find('button[aria-label="メニュー"]').click

      expect(page).to have_button('ログアウト')
    end

    it 'ログインすると自動ログイン用のCookieが設定される' do
      user = create_user

      visit new_user_session_path

      login(user)

      expect(page.driver.browser.manage.all_cookies)
        .to include(hash_including(name: 'remember_user_token'))
    end

    it '自動ログインするとログイン状態の保持期間が延長される' do
      user = create_user

      login(user)

      cookie = page.driver.browser.manage.all_cookies
                   .find { |cookie| cookie[:name] == 'remember_user_token' }

      original_expires = cookie[:expires]

      travel_to 1.week.from_now do
        page.driver.browser.manage.delete_cookie('_tree_calculation_session')

        visit root_path

        expect(page).to have_text(user.name)

        new_cookie = page.driver.browser.manage.all_cookies
                         .find { |cookie| cookie[:name] == 'remember_user_token' }

        expect(new_cookie[:expires]).to be > original_expires
      end
    end

    it 'セッションがなくなっても自動ログインできる' do
      user = create_user

      login(user)

      page.driver.browser.manage.delete_cookie('_tree_calculation_session')

      visit root_path

      expect(page).to have_text(user.name)
    end
  end

  describe 'ログアウト' do
    it 'ログイン中のユーザーがログアウトできる' do
      user = create_user

      visit new_user_session_path

      login(user)

      find('button[aria-label="メニュー"]').click
      click_button 'ログアウト'

      expect(page).to have_current_path(root_path)

      find('button[aria-label="メニュー"]').click

      expect(page).to have_link('ログイン')
    end

    it 'ログアウトすると自動ログインされない' do
      user = create_user

      visit new_user_session_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'

      find('button[aria-label="メニュー"]').click
      click_button 'ログアウト'

      visit root_path

      find('button[aria-label="メニュー"]').click

      expect(page).to have_link('ログイン')
      expect(page).to have_no_text(user.name)
    end
  end
end
