# frozen_string_literal: true

require 'rails_helper'

# 見積の設定は、会社の管理者(admin)だけが、自社の分だけ見られる・変えられる。
RSpec.describe 'Admin::EstimateSettings', type: :request do
  def build_user(organization, email, role)
    User.create!(
      name: '山田太郎', email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:admin) { build_user(organization, 'admin@example.com', :admin) }
  let(:worker) { build_user(organization, 'worker@example.com', :worker) }
  let(:valid_params) do
    {
      estimate_setting: {
        overhead_rate: '8', margin_rate: '25', margin_basis: 'cost', rounding_unit: '100', rounding_mode: 'round'
      }
    }
  end

  describe '未認証ユーザー' do
    it '開くとログイン画面へ移動し、更新もできない' do
      get edit_admin_estimate_setting_path
      expect(response).to redirect_to(new_user_session_path)

      patch admin_estimate_setting_path, params: valid_params
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe '作業者・運営は見積の設定を使えない' do
    it '作業者は開けず、更新もできない' do
      sign_in worker

      get edit_admin_estimate_setting_path
      expect(response).to have_http_status(:forbidden)

      patch admin_estimate_setting_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
      expect(EstimateSetting.count).to eq(0)
    end

    it '運営(operator)も使えない（会社の業務データは運営は見ない）' do
      sign_in build_user(organization, 'operator@example.com', :operator)

      get edit_admin_estimate_setting_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '管理者' do
    before { sign_in admin }

    it '初めて開いたとき、初期値で設定を作って表示する' do
      expect { get edit_admin_estimate_setting_path }.to change(EstimateSetting, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('見積の設定')
      expect(EstimateSetting.find_by(organization: organization)).to have_attributes(margin_rate: 30)
    end

    it '2回目以降は、設定を増やさず、普通に開ける' do
      get edit_admin_estimate_setting_path

      expect { get edit_admin_estimate_setting_path }.not_to change(EstimateSetting, :count)
      expect(response).to have_http_status(:ok)
    end

    it '全角数字・カンマ区切りで入力しても、更新できる' do
      patch admin_estimate_setting_path, params: { estimate_setting: { margin_rate: '３５．５', overhead_rate: '１２' } }

      expect(response).to redirect_to(edit_admin_estimate_setting_path)
      expect(EstimateSetting.find_by(organization: organization)).to have_attributes(
        margin_rate: BigDecimal('35.5'), overhead_rate: 12
      )
    end

    it '㎡単価の端数の単位を変えられる。一覧にない値はエラーにする' do
      patch admin_estimate_setting_path, params: { estimate_setting: { area_price_rounding_unit: '0.1' } }
      expect(EstimateSetting.find_by(organization: organization).area_price_rounding_unit).to eq(BigDecimal('0.1'))

      patch admin_estimate_setting_path, params: { estimate_setting: { area_price_rounding_unit: '5' } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it '設定を更新できる' do
      patch admin_estimate_setting_path, params: valid_params

      expect(response).to redirect_to(edit_admin_estimate_setting_path)
      expect(EstimateSetting.find_by(organization: organization)).to have_attributes(
        overhead_rate: 8, margin_rate: 25, margin_basis: 'cost', rounding_unit: 100, rounding_mode: 'round'
      )
    end

    it '不正な値なら更新せず、エラーを表示する（売価に対する利益率が100%）' do
      patch admin_estimate_setting_path, params: { estimate_setting: { margin_rate: '100' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('利益率は100未満にしてください')
      expect(EstimateSetting.find_by(organization: organization).margin_rate).to eq(30)
    end

    it '未知の端数の処理を送られても、エラーになるだけで落ちない' do
      patch admin_estimate_setting_path, params: { estimate_setting: { rounding_mode: 'bogus' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '他社の設定は変わらない' do
      other = EstimateSetting.for(other_organization)
      other.update!(margin_rate: 10)

      patch admin_estimate_setting_path, params: valid_params

      expect(other.reload.margin_rate).to eq(10)
    end
  end
end
