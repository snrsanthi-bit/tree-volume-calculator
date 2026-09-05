# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '材積計算', type: :system do
  before do
    driven_by :selenium_firefox
  end

  context 'when 不正な値の場合' do
    it '直径が0の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '太さ (直径 cm)', with: 0
      fill_in '長さ (高さ m)', with: 4

      click_button '計算する'

      expect(page).to have_text('直径は0より大きい値を入力してください')
      expect(page).to have_no_css('#volume-value')
    end

    it '直径が負の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '太さ (直径 cm)', with: -1
      fill_in '長さ (高さ m)', with: 4

      click_button '計算する'

      expect(page).to have_text('直径は0より大きい値を入力してください')
      expect(page).to have_no_css('#volume-value')
    end

    it '高さが0の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '太さ (直径 cm)', with: 30
      fill_in '長さ (高さ m)', with: 0

      click_button '計算する'

      expect(page).to have_text('高さは0より大きい値を入力してください')
      expect(page).to have_no_css('#volume-value')
    end

    it '高さが負の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '太さ (直径 cm)', with: 30
      fill_in '長さ (高さ m)', with: -1

      click_button '計算する'

      expect(page).to have_text('高さは0より大きい値を入力してください')
      expect(page).to have_no_css('#volume-value')
    end
  end
end
