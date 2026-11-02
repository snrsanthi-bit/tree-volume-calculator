# frozen_string_literal: true

require 'rails_helper'

# 面積を入力するときの単位の初期値（管理者が会社ごとに決める）。
RSpec.describe 'Admin::EstimateSettings 面積の入力単位', type: :request do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:admin) do
    User.create!(name: '管理者太郎', email: 'admin@example.com', role: :admin, organization: organization,
                 password: 'password123', password_confirmation: 'password123')
  end

  before { sign_in admin }

  it '初期値は㎡で、haに変えられる' do
    expect(EstimateSetting.for(organization).area_input_unit).to eq('m2')

    patch admin_estimate_setting_path, params: { estimate_setting: { area_input_unit: 'ha' } }

    expect(response).to redirect_to(edit_admin_estimate_setting_path)
    expect(EstimateSetting.for(organization).area_input_unit).to eq('ha')
  end

  it '知らない単位は保存せず、エラーにする' do
    patch admin_estimate_setting_path, params: { estimate_setting: { area_input_unit: 'km2' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(EstimateSetting.for(organization).area_input_unit).to eq('m2')
  end

  it '設定の画面に、入力単位の選択がある' do
    get edit_admin_estimate_setting_path

    expect(response.body).to include('面積を入力するときの単位')
  end
end
