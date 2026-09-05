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

      expect(page).to have_css('#areaResult', text: '6.0')
      expect(page).to have_css('#haResult', text: '0.0006')
    end

    it '辺Aが未入力の場合はエラーメッセージを表示する' do
      visit root_path

      fill_triangle('', 4, 5)

      click_button '面積を計算する'

      expect(page).to have_text('辺Aは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Bが未入力の場合はエラーメッセージを表示する' do
      visit root_path

      fill_triangle(3, '', 5)

      click_button '面積を計算する'

      expect(page).to have_text('辺Bは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Cが未入力の場合はエラーメッセージを表示する' do
      visit root_path

      fill_triangle(3, 4, '')

      click_button '面積を計算する'

      expect(page).to have_text('辺Cは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Aが0の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '辺 A (m)', with: 0
      fill_in '辺 B (m)', with: 4
      fill_in '辺 C (m)', with: 5

      click_button '面積を計算する'

      expect(page).to have_text('辺Aは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Bが0の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '辺 A (m)', with: 3
      fill_in '辺 B (m)', with: 0
      fill_in '辺 C (m)', with: 5

      click_button '面積を計算する'

      expect(page).to have_text('辺Bは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Cが0の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '辺 A (m)', with: 3
      fill_in '辺 B (m)', with: 4
      fill_in '辺 C (m)', with: 0

      click_button '面積を計算する'

      expect(page).to have_text('辺Cは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Aが負の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '辺 A (m)', with: -1
      fill_in '辺 B (m)', with: 4
      fill_in '辺 C (m)', with: 5

      click_button '面積を計算する'

      expect(page).to have_text('辺Aは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Bが負の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '辺 A (m)', with: 3
      fill_in '辺 B (m)', with: -1
      fill_in '辺 C (m)', with: 5

      click_button '面積を計算する'

      expect(page).to have_text('辺Bは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '辺Cが負の場合はエラーメッセージを表示する' do
      visit root_path

      fill_in '辺 A (m)', with: 3
      fill_in '辺 B (m)', with: 4
      fill_in '辺 C (m)', with: -1

      click_button '面積を計算する'

      expect(page).to have_text('辺Cは0より大きい値を入力してください')
      expect(page).to have_no_css('#areaResult')
      expect(page).to have_no_css('#haResult')
    end

    it '小さい値でも計算できる' do
      visit root_path

      fill_in '辺 A (m)', with: 0.11
      fill_in '辺 B (m)', with: 0.11
      fill_in '辺 C (m)', with: 0.11

      click_button '面積を計算する'

      expect(page).to have_css('#areaResult', text: '0.01')
      expect(page).to have_css('#haResult', text: '0.0')
    end

    it '大きい数字でも計算できる' do
      visit root_path

      fill_in '辺 A (m)', with: 99_999_990
      fill_in '辺 B (m)', with: 99_999_990
      fill_in '辺 C (m)', with: 99_999_990

      click_button '面積を計算する'

      expect(page).to have_css('#areaResult', text: '4330126152896832.5')
      expect(page).to have_css('#haResult', text: '433012615289.6833')
    end

    describe '三角形が成立しない場合' do
      [
        [1, 2, 10],
        [1, 10, 2],
        [10, 1, 2]
      ].each do |a, b, c|
        it "辺 #{a}, #{b}, #{c} では三角形を作れない" do
          visit root_path

          fill_triangle(a, b, c)

          click_button '面積を計算する'

          expect(page).to have_text('この辺の長さでは三角形を作れません')
          expect(page).to have_no_css('#areaResult')
          expect(page).to have_no_css('#haResult')
        end
      end
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

      expect(page).to have_css('#areaResult', text: '12.0')
      expect(page).to have_css('#haResult', text: '0.0012')
    end
  end
end
