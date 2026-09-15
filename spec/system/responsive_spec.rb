# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'レスポンシブ対応', type: :system do
  before do
    driven_by :selenium_firefox
  end

  def set_viewport(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def expect_no_horizontal_scroll
    expect(
      page.evaluate_script(
        'document.documentElement.scrollWidth <= document.documentElement.clientWidth'
      )
    ).to be(true)
  end

  describe 'スマートフォン' do
    before do
      visit root_path
      set_viewport(375, 667)
    end

    it '横スクロールが発生しない' do
      expect_no_horizontal_scroll
    end

    it '材積計算の入力欄がタップしやすいサイズになっている' do
      expect(page).to have_field('太さ (直径 cm)')
      expect(page).to have_field('長さ (高さ m)')

      expect(page.find('input[name="dbh"]')[:class]).to include('h-16')
      expect(page.find('input[name="height"]')[:class]).to include('h-16')
    end

    it '材積計算ボタンがタップしやすいサイズになっている' do
      expect(page.find('input[type="submit"]')[:class]).to include('py-5')
    end

    it '材積計算ができる' do
      fill_in '太さ (直径 cm)', with: 30
      fill_in '長さ (高さ m)', with: 4

      click_button '計算する'

      expect(page).to have_css('#volum-value', text: '0.565')
    end

    it '地積計算ができる' do
      visit area_path

      fill_in '辺 A (m)', with: 3
      fill_in '辺 B (m)', with: 4
      fill_in '辺 C (m)', with: 5

      click_button '面積を計算する'

      expect(page).to have_css('#areaResult', text: '6.0')
      expect(page).to have_css('#haResult', text: '0.0006')
    end
  end

  describe 'タブレット' do
    before do
      visit root_path
      set_viewport(768, 1024)
    end

    it '横スクロールが発生しない' do
      expect_no_horizontal_scroll
    end
  end

  describe 'PC' do
    before do
      visit root_path
      set_viewport(1440, 900)
    end

    it '横スクロールが発生しない' do
      expect_no_horizontal_scroll
    end
  end

  describe 'ヘッダー' do
    before do
      visit root_path
    end

    it 'TreeCalculationのロゴが表示される' do
      expect(page).to have_css('header', text: 'TreeCalculation')
    end

    it 'ハンバーガーメニューが表示される' do
      expect(page).to have_css('button[aria-label="メニュー"]')
    end

    it 'メニューから材積計算ページへ移動できる' do
      find('button[aria-label="メニュー"]').click

      click_link '材積計算'

      expect(page).to have_current_path(root_path)
    end

    it 'メニューから地積計算ページへ移動できる' do
      find('button[aria-label="メニュー"]').click

      click_link '地積計算'

      expect(page).to have_current_path(area_path)
    end

    it 'ハンバーガーメニューを開くとメニュー項目が表示される' do
      find('button[aria-label="メニュー"]').click

      expect(page).to have_link('材積計算')
      expect(page).to have_link('地積計算')
    end
  end

  describe 'ページ' do
    it '材積計算ページを表示できる' do
      visit root_path

      expect(page).to have_text('材積計算')
    end

    it '地積計算ページを表示できる' do
      visit area_path

      expect(page).to have_text('地積計算')
    end
  end
end
