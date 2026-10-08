# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'プラポリ', type: :system do
  before do
    driven_by :firefox_japan
  end

  describe '/terms が表示される' do
    it '未ログインでも利用規約を閲覧できる' do
      visit terms_path

      expect(page).to have_text('利用規約')
    end
  end

  describe '/privacy_policy が表示される' do
    it '未ログインでもプライバシーポリシーを閲覧できる' do
      visit privacy_policy_path

      expect(page).to have_text('プライバシーポリシー')
    end
  end

  describe 'フッターから両方へ行ける' do
    it '利用規約へのリンクがある' do
      visit root_path

      expect(page).to have_link('利用規約', href: terms_path)
    end

    it 'プライバシーポリシーへのリンクがある' do
      visit root_path

      expect(page).to have_link(
        'プライバシーポリシー',
        href: privacy_policy_path
      )
    end
  end

  describe 'スマホで横スクロールしない' do
    it '利用規約ページで横スクロールが発生しない' do
      visit terms_path
      set_viewport(375, 667)

      expect_no_horizontal_scroll
    end

    it 'プライバシーポリシーページで横スクロールが発生しない' do
      visit privacy_policy_path
      set_viewport(375, 667)

      expect_no_horizontal_scroll
    end
  end
end
