# frozen_string_literal: true

require 'rails_helper'

# 作業範囲の画面の「見積に取り込む」は、管理者にだけ出る。
RSpec.describe 'WorkAreas 見積への取り込み', type: :request do
  def build_user(organization, email, role)
    User.create!(
      name: '山田太郎', email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:work_area) do
    organization.work_areas.create!(name: '北側', coordinates: [[35.0, 139.0], [35.0, 139.001], [35.001, 139.0]])
  end

  it '管理者には、自社の見積を選ぶ取り込みの欄が出る' do
    Estimate.build_for(organization, name: '現場A').save!
    sign_in build_user(organization, 'admin@example.com', :admin)

    get work_area_path(work_area)

    expect(response.body).to include('見積に取り込む').and include('現場A')
  end

  it '他社の見積は選択肢に出ない' do
    other = Organization.create!(name: '林業会社B')
    Estimate.build_for(other, name: '他社の現場').save!
    sign_in build_user(organization, 'admin@example.com', :admin)

    get work_area_path(work_area)

    expect(response.body).not_to include('他社の現場')
  end

  it '見積がなくても、新しい見積を作って取り込める' do
    sign_in build_user(organization, 'admin@example.com', :admin)

    get work_area_path(work_area)

    expect(response.body).to include('新しい見積を作る（名前: 北側）')
  end

  it '作業者には、取り込みの欄が出ない' do
    Estimate.build_for(organization, name: '現場A').save!
    sign_in build_user(organization, 'worker@example.com', :worker)

    get work_area_path(work_area)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('見積に取り込む')
    expect(response.body).not_to include('現場A')
  end
end
