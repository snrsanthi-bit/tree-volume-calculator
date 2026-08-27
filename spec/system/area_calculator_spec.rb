# frozen_string_literal: true

require 'rails_helper'
RSpec.describe '地積計算', type: :system do
  before do
    driven_by :selenium_firefox
  end

  def fill_triangle(side_a, side_b, side_c)
    fill_in '辺 A (m)', with: side_a
    fill_in '辺 B (m)', with: side_b
    fill_in '辺 C (m)', with: side_c
  end

  describe '三角形1つの場合' do
    it '正しい面積が表示される' do
      visit root_path

      fill_in '辺 A (m)', with: 3
      fill_in '辺 B (m)', with: 4
      fill_in '辺 C (m)', with: 5

      click_button '面積を計算する'

      expect(page).to have_text('6.0')
      expect(page).to have_text('0.0006')
    end

    it '辺が0の場合は0になる' do
      visit root_path

      fill_in '辺 A (m)', with: 0
      fill_in '辺 B (m)', with: 0
      fill_in '辺 C (m)', with: 0

      click_button '面積を計算する'

      expect(page).to have_text('0.0')
      expect(page).to have_text('0.0')
    end

    it '小さい値でも計算できる' do
      visit root_path

      fill_in '辺 A (m)', with: 0.11
      fill_in '辺 B (m)', with: 0.11
      fill_in '辺 C (m)', with: 0.11

      click_button '面積を計算する'

      expect(page).to have_text('0.01')
      expect(page).to have_text('0.0')
    end

    it '大きい数字でも計算できる' do
      visit root_path

      fill_in '辺 A (m)', with: 99_999_990
      fill_in '辺 B (m)', with: 99_999_990
      fill_in '辺 C (m)', with: 99_999_990

      click_button '面積を計算する'

      expect(page).to have_text('4330126152896832.5')
      expect(page).to have_text('433012615289.6833')
    end
  end

  describe '三角形複数の場合' do
    it '正しい面積が表示される' do
      visit root_path

      within first('.triangle') do
        fill_triangle(3, 4, 5)
      end

      click_button '三角形を追加'

      expect(page).to have_css('.triangle', count: 2)

      within all('.triangle').last do
        fill_triangle(3, 4, 5)
      end

      click_button '面積を計算する'

      expect(page).to have_text('12.0')
      expect(page).to have_text('0.0012')
    end
  end
end
