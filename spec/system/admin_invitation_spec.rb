# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '管理者によるアカウント作成と招待', type: :system do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:admin) do
    User.create!(name: '管理者太郎', email: 'admin@example.com', role: :admin, organization: organization,
                 password: 'password123', password_confirmation: 'password123')
  end

  def login(user, password)
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: password
    click_button 'Log in'
  end

  def logout
    find('button[aria-label="メニュー"]').click
    click_button 'ログアウト'
  end

  def create_worker_and_get_invitation_url
    visit admin_users_path
    click_link '作業者を追加'
    fill_in '名前', with: '新人作業員'
    fill_in 'メールアドレス', with: 'new-worker@example.com'
    click_button '追加する'

    find_by_id('invitation-url').value
  end

  before { driven_by :firefox_japan }

  it '管理者がユーザーを追加し、招待URLからパスワードを設定してトップ画面に入れる' do
    login(admin, 'password123')
    url = create_worker_and_get_invitation_url
    logout

    visit url
    fill_in 'user_password', with: 'new-password-123'
    fill_in 'user_password_confirmation', with: 'new-password-123'
    click_button 'パスワードを設定してログイン'

    expect(page).to have_current_path(root_path)
    expect(page).to have_text('新人作業員')

    find('button[aria-label="メニュー"]').click
    expect(page).to have_link('作業範囲一覧')
    expect(page).to have_no_link('作業者の管理')
  end

  it '招待URLは画面を移動すると再表示されない' do
    login(admin, 'password123')
    create_worker_and_get_invitation_url

    visit admin_users_path

    expect(page).to have_css('h1', text: '作業者の管理') # 画面の表示を待ってから、URLが無いことを確かめる
    expect(page).to have_no_css('#invitation-url')
  end

  it '作業者は管理画面を開けない' do
    worker = User.create!(name: '作業者花子', email: 'worker@example.com', role: :worker, organization: organization,
                          password: 'password123', password_confirmation: 'password123')
    login(worker, 'password123')

    visit admin_users_path

    expect(page).to have_text('この画面は利用できません')
  end
end
