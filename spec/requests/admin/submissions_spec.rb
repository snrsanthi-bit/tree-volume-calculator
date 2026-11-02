# frozen_string_literal: true

require 'rails_helper'

# 提出画面（元請けに出す見積書のプレビュー）。管理者だけが、自社の見積について見られる。
RSpec.describe 'Admin::Submissions', type: :request do
  include EstimateSampleHelpers

  def build_user(organization, email, role)
    User.create!(
      name: '管理者太郎', email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:estimate) { create_sample_estimate(organization).tap { |sample| sample.update!(client_name: '山田建設') } }

  # 元請けに見せてはいけない言葉
  def forbidden_words
    %w[原価 利益 諸経費 直接費]
  end

  def switch_format(format)
    patch admin_estimate_submission_path(estimate), params: { estimate: { submission_format: format } }
  end

  describe '表示' do
    before { sign_in build_user(organization, 'admin@example.com', :admin) }

    it '見積番号・宛名・現場名・内訳・税抜 / 消費税 / 税込が出る' do
      get admin_estimate_submission_path(estimate)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('御見積書', '見積-0001', '山田建設 御中', '北側作業範囲')
      expect(response.body).to include('伐採費', '252,000円', '263,000円')
      expect(response.body).to include('929,000円', '92,900円', '1,021,900円')
      expect(response.body).to include('小計（税抜）', '消費税（10%）', '合計（税込）')
    end

    it '原価・利益率などの、見えてはいけない金額と言葉が、画面に含まれない' do
      get admin_estimate_submission_path(estimate)

      forbidden_words.each { |word| expect(response.body).not_to include(word) }
      # 原価（649,950円）・直接費（619,000円）・利益（279,050円）の金額も出ない
      expect(response.body).not_to include('649,950', '619,000', '279,050')
    end

    it '自社の情報と備考が、設定したとおりに出る' do
      EstimateSetting.for(organization).update!(
        issuer_name: '株式会社A林業', issuer_address: '長野県1-2-3', issuer_phone: '026-000-0000',
        submission_note: '有効期限は1か月です'
      )

      get admin_estimate_submission_path(estimate)

      expect(response.body).to include('株式会社A林業', '長野県1-2-3', 'TEL 026-000-0000', '有効期限は1か月です')
    end

    it '宛名や自社の住所が空なら、画面に知らせる（印刷される部分には出さない）' do
      estimate.update!(client_name: nil)

      get admin_estimate_submission_path(estimate)

      expect(response.body).to include('submission-warning-client', 'submission-warning-issuer')
      expect(response.body).not_to include('御中')
    end

    it '明細がない見積は、理由を出して、提出書は出さない' do
      empty = Estimate.build_for(organization, name: '現場B').tap(&:save!)

      get admin_estimate_submission_path(empty)

      expect(response.body).to include('この見積には明細がありません')
      expect(response.body).not_to include('submission-sheet')
    end
  end

  describe '提出の形式' do
    before { sign_in build_user(organization, 'admin@example.com', :admin) }

    it '㎡単価に切り替えると、面積・単価・金額が出て、金額（税抜）は変わらない' do
      switch_format('area_price')
      expect(response).to redirect_to(admin_estimate_submission_path(estimate))
      expect(estimate.reload.submission_format).to eq('area_price')

      get admin_estimate_submission_path(estimate)

      expect(response.body).to include('作業費', '8,420', '111', '929,000円', '1,021,900円')
      expect(response.body).to include('934,620円', '金額より5,620円多くなります')
      expect(response.body).to include('submission-area-price-note')
    end

    it '面積が入っていない見積は、㎡単価では理由が出て、提出書は出ない' do
      estimate.update!(area: nil)
      switch_format('area_price')

      get admin_estimate_submission_path(estimate)

      expect(response.body).to include('面積が入っていないため')
      expect(response.body).not_to include('submission-sheet')
    end

    it '項目別の内訳に戻せる' do
      switch_format('area_price')
      switch_format('breakdown')

      expect(estimate.reload.submission_format).to eq('breakdown')
    end

    it '知らない形式は受け付けず、形式は変わらない' do
      switch_format('unknown')

      expect(response).to redirect_to(admin_estimate_submission_path(estimate))
      expect(estimate.reload.submission_format).to eq('breakdown')
    end
  end

  describe '権限' do
    it '未認証ならログイン画面へ移動する' do
      get admin_estimate_submission_path(estimate)

      expect(response).to redirect_to(new_user_session_path)
    end

    it '作業者は、見ることも形式を変えることもできない' do
      sign_in build_user(organization, 'worker@example.com', :worker)

      get admin_estimate_submission_path(estimate)
      expect(response).to have_http_status(:forbidden)

      switch_format('area_price')
      expect(response).to have_http_status(:forbidden)
      expect(estimate.reload.submission_format).to eq('breakdown')
    end

    it '他社の見積は、見る・変えるのどちらも404' do
      other = Organization.create!(name: '林業会社B')
      other_estimate = create_sample_estimate(other)
      admin = build_user(organization, 'admin@example.com', :admin)
      sign_in admin

      get admin_estimate_submission_path(other_estimate)
      expect(response).to have_http_status(:not_found)

      # 404 になったリクエストではログインの状態が保存されないので、もう一度ログインする
      sign_in admin
      patch admin_estimate_submission_path(other_estimate), params: { estimate: { submission_format: 'area_price' } }
      expect(response).to have_http_status(:not_found)
      expect(other_estimate.reload.submission_format).to eq('breakdown')
    end
  end

  it '見積の画面から、提出画面へのリンクがある' do
    sign_in build_user(organization, 'admin@example.com', :admin)

    get admin_estimate_path(estimate)

    expect(response.body).to include(admin_estimate_submission_path(estimate))
    expect(response.body).to include('単価は、税抜の金額で入れてください')
  end
end
