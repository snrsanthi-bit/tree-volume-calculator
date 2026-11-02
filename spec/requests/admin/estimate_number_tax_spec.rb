# frozen_string_literal: true

require 'rails_helper'

# 見積番号・宛名・消費税・検索の画面。
RSpec.describe 'Admin::Estimates 見積番号・消費税・検索', type: :request do
  include EstimateSampleHelpers

  def build_user(organization, email, role)
    User.create!(
      name: '管理者太郎', email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:estimate) { create_sample_estimate(organization) }

  before { sign_in build_user(organization, 'admin@example.com', :admin) }

  describe '作成' do
    it '見積番号が自動で付き、宛名を入れられる。番号はパラメータで指定できない' do
      post admin_estimates_path, params: { estimate: { name: '現場A', client_name: '山田建設', number: 99 } }

      created = organization.estimates.last
      expect(created).to have_attributes(number: 1, client_name: '山田建設')
      expect(response).to redirect_to(admin_estimate_path(created))
    end

    it '編集の画面に番号が出て、更新しても番号は変わらない' do
      get edit_admin_estimate_path(estimate)
      expect(response.body).to include('見積-0001（変更できません）')

      patch admin_estimate_path(estimate), params: { estimate: { name: '現場A', client_name: '宛名変更', number: 5 } }

      expect(estimate.reload).to have_attributes(number: 1, client_name: '宛名変更')
    end
  end

  describe '金額の表示' do
    it '見積の画面に、売価（税抜）・消費税・売価（税込）が出る' do
      get admin_estimate_path(estimate)

      expect(response.body).to include('売価（税抜）')
      expect(response.body).to include('929,000円').and include('92,900円').and include('1,021,900円')
      expect(response.body).to include('見積-0001')
    end

    it '一覧にも、税抜と税込が書かれている' do
      estimate

      get admin_estimates_path

      expect(response.body).to include('929,000円').and include('1,021,900円')
      expect(response.body).to include('（税抜）').and include('（税込）')
    end

    it '設定の税率を変えても、作成済みの見積の消費税は変わらない' do
      estimate
      EstimateSetting.for(organization).update!(tax_rate: 8)

      get admin_estimate_path(estimate)

      expect(response.body).to include('92,900円').and include('1,021,900円')
    end
  end

  describe '検索' do
    before do
      create_sample_estimate(organization, name: '北側作業範囲')
      organization.estimates.last.update!(client_name: '山田建設')
      create_sample_estimate(organization, name: '南側作業範囲')
      create_sample_estimate(other_organization, name: '他社の北側')
    end

    it '現場名・宛名・番号で絞れる' do
      get admin_estimates_path, params: { q: '山田' }
      expect(response.body).to include('北側作業範囲').and include('山田建設')
      expect(response.body).not_to include('南側作業範囲')

      get admin_estimates_path, params: { q: '見積-0002' }
      expect(response.body).to include('南側作業範囲')
      expect(response.body).not_to include('北側作業範囲')
    end

    it '合う見積がなければ、そう表示する。他社の見積は出ない' do
      get admin_estimates_path, params: { q: '北側' }

      expect(response.body).not_to include('他社の北側')

      get admin_estimates_path, params: { q: 'なにもない' }
      expect(response.body).to include('「なにもない」に合う見積はありません')
    end
  end
end
