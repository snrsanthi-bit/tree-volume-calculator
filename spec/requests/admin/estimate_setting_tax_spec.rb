# frozen_string_literal: true

require 'rails_helper'

# 見積の設定: 消費税率・消費税の端数の処理・見積番号の頭の文字。
RSpec.describe 'Admin::EstimateSettings 消費税・見積番号', type: :request do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:admin) do
    User.create!(name: '管理者太郎', email: 'admin@example.com', role: :admin, organization: organization,
                 password: 'password123', password_confirmation: 'password123')
  end

  before { sign_in admin }

  def update_setting(**attributes)
    patch admin_estimate_setting_path, params: { estimate_setting: attributes }
  end

  it '初期値は、税率10%・切り捨て・「見積-」' do
    expect(EstimateSetting.for(organization)).to have_attributes(
      tax_rate: 10, tax_rounding_mode: 'floor', number_prefix: '見積-', last_estimate_number: 0
    )
  end

  it '税率・端数の処理・頭の文字を変えられる（全角の数字も受け付ける）' do
    update_setting(tax_rate: '８', tax_rounding_mode: 'round', number_prefix: 'No.')

    expect(response).to redirect_to(edit_admin_estimate_setting_path)
    expect(EstimateSetting.for(organization)).to have_attributes(
      tax_rate: 8, tax_rounding_mode: 'round', number_prefix: 'No.'
    )
  end

  it '税率が範囲外・頭の文字が長すぎるときは保存しない' do
    update_setting(tax_rate: '101')
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('消費税率は100以下にしてください')

    update_setting(number_prefix: 'あ' * 11)
    expect(response).to have_http_status(:unprocessable_content)
    expect(EstimateSetting.for(organization).number_prefix).to eq('見積-')
  end

  it '知らない端数の処理は保存しない' do
    update_setting(tax_rounding_mode: 'unknown')

    expect(response).to have_http_status(:unprocessable_content)
    expect(EstimateSetting.for(organization).tax_rounding_mode).to eq('floor')
  end

  it '設定の画面に、消費税率と見積番号の項目がある。番号の最後の値は変えられない' do
    get edit_admin_estimate_setting_path
    expect(response.body).to include('消費税率（%）').and include('見積番号の頭の文字')

    update_setting(last_estimate_number: 500)
    expect(EstimateSetting.for(organization).last_estimate_number).to eq(0)
  end
end
