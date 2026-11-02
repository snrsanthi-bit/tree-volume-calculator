# frozen_string_literal: true

require 'rails_helper'

# 見積の面積は、㎡ / ha のどちらでも入力できる。保存は㎡。
RSpec.describe 'Admin::Estimates 面積の単位', type: :request do
  def build_user(organization, email, role, name: '山田太郎')
    User.create!(
      name: name, email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:admin) { build_user(organization, 'admin@example.com', :admin, name: '管理者太郎') }
  let(:estimate) { Estimate.build_for(organization, name: '現場A', area: 8420).tap(&:save!) }

  let(:work_area) do
    organization.work_areas.create!(name: '北側', coordinates: [[35.0, 139.0], [35.0, 139.001], [35.001, 139.0]])
  end

  before { sign_in admin }

  def create_with(area, unit)
    post admin_estimates_path, params: { estimate: { name: '現場B', area: area, area_unit: unit } }
    Estimate.find_by(name: '現場B')
  end

  it 'haで入力した面積は、㎡にして保存する' do
    expect(create_with('0.842', 'ha').area).to eq(8420)
  end

  it '㎡で入力した面積は、そのまま保存する。単位が空でも㎡' do
    expect(create_with('8420', 'm2').area).to eq(8420)

    Estimate.find_by(name: '現場B').destroy!
    expect(create_with('8420', '').area).to eq(8420)
  end

  it '知らない単位は、㎡として扱わずにエラーにする' do
    expect(create_with('8420', 'km2')).to be_nil

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('面積の単位が正しくありません')
  end

  it '更新でも、知らない単位なら面積を変えない' do
    patch admin_estimate_path(estimate), params: { estimate: { name: '現場A', area: '1', area_unit: 'km2' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(estimate.reload.area).to eq(8420)
  end

  it '新規作成の画面は、設定した単位が初めから選ばれている' do
    EstimateSetting.for(organization).update!(area_input_unit: :ha)

    get new_admin_estimate_path

    expect(response.body).to include('selected="selected" value="ha"')
  end

  it '設定が㎡なら、㎡が選ばれている' do
    get new_admin_estimate_path

    expect(response.body).to include('selected="selected" value="m2"')
  end

  it '編集の画面は、設定がhaなら面積をhaに直して表示し、保存されている面積も併記する' do
    EstimateSetting.for(organization).update!(area_input_unit: :ha)

    get edit_admin_estimate_path(estimate)

    expect(response.body).to include('value="0.842"')
    expect(response.body).to include('8,420㎡（0.842ha）')
  end

  it 'haで入力した面積が不正なら保存せず、入力した値と単位のまま、エラーを表示する' do
    post admin_estimates_path, params: { estimate: { name: '現場B', area: '-5', area_unit: 'ha' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('value="-5"').and include('selected="selected" value="ha"')
    expect(response.body).to include('面積は0より大きい値にしてください')
  end

  it '見積の画面に、㎡とhaを併記する' do
    get admin_estimate_path(estimate)

    expect(response.body).to include('8,420㎡（0.842ha）')
  end

  it '取り込んだ値は、面積を変えずに名前だけ直しても、取り込んだ値のまま' do
    estimate.import_area(work_area, 8420)

    patch admin_estimate_path(estimate), params: { estimate: { name: '名前だけ', area: '8420', area_unit: 'm2' } }

    expect(estimate.reload).to have_attributes(name: '名前だけ', area_from_map: true)
  end
end
