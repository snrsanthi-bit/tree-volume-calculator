# frozen_string_literal: true

require 'rails_helper'

# 作業範囲の実測地積を、既存の見積に取り込む（管理者だけ・自社の分だけ）。
RSpec.describe 'Admin::AreaImports', type: :request do
  def build_user(organization, email, role, name: '山田太郎')
    User.create!(
      name: name, email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  def create_work_area(owner, name: '北側')
    owner.work_areas.create!(name: name, coordinates: [[35.0, 139.0], [35.0, 139.001], [35.001, 139.0]])
  end

  def import_params(estimate, work_area, area: '8420.5', kind: 'measured')
    { area_import: { estimate_id: estimate&.id, work_area_id: work_area.id, area: area, kind: kind } }
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:admin) { build_user(organization, 'admin@example.com', :admin, name: '管理者太郎') }
  let(:estimate) { Estimate.build_for(organization, name: '現場A', area: 100).tap(&:save!) }
  let(:work_area) { create_work_area(organization) }

  describe '未認証・作業者' do
    it '未認証ならログイン画面へ移動し、取り込めない' do
      post admin_area_imports_path, params: import_params(estimate, work_area)

      expect(response).to redirect_to(new_user_session_path)
      expect(estimate.reload.area).to eq(100)
    end

    it '作業者は取り込めない' do
      sign_in build_user(organization, 'worker@example.com', :worker)

      post admin_area_imports_path, params: import_params(estimate, work_area)

      expect(response).to have_http_status(:forbidden)
      expect(estimate.reload.area).to eq(100)
    end
  end

  describe '管理者' do
    before { sign_in admin }

    it '見積の面積を上書きし、取り込んだ値として見積の画面に移動する' do
      post admin_area_imports_path, params: import_params(estimate, work_area)

      expect(response).to redirect_to(admin_estimate_path(estimate))
      expect(response).to have_http_status(:see_other)
      expect(estimate.reload).to have_attributes(area: BigDecimal('8420.5'), work_area: work_area, area_from_map: true)
    end

    it '取り込み先を選ばないと、作業範囲の名前で新しい見積を作って取り込む' do
      expect { post admin_area_imports_path, params: import_params(nil, work_area) }
        .to change(organization.estimates, :count).by(1)

      created = organization.estimates.last
      expect(response).to redirect_to(admin_estimate_path(created))
      expect(created).to have_attributes(
        name: '北側', area: BigDecimal('8420.5'), work_area: work_area, area_from_map: true
      )
    end

    it '新しい見積は、作業範囲の名前が長くても50文字までにして作る' do
      long = organization.work_areas.create!(name: 'あ' * 80, coordinates: work_area.coordinates)

      post admin_area_imports_path, params: import_params(nil, long)

      expect(organization.estimates.last.name).to eq('あ' * 50)
    end

    it '新しい見積を作る取り込みで面積が空なら、見積を作らない' do
      expect { post admin_area_imports_path, params: import_params(nil, work_area, area: '') }
        .not_to change(Estimate, :count)
      expect(response).to redirect_to(work_area_path(work_area, estimate_id: 'new'))
    end

    it '概算面積も取り込める。見積の画面に、概算であることを表示する' do
      post admin_area_imports_path, params: import_params(estimate, work_area, kind: 'estimated')

      expect(estimate.reload).to have_attributes(area: BigDecimal('8420.5'), area_source_kind: 'estimated')
      get admin_estimate_path(estimate)
      expect(response.body).to include('概算地積').and include('作業範囲「北側」')
    end

    it '種類が不正なら取り込まない' do
      post admin_area_imports_path, params: import_params(estimate, work_area, kind: 'unknown')

      expect(response).to redirect_to(work_area_path(work_area, estimate_id: estimate.id))
      expect(estimate.reload).to have_attributes(area: 100, area_from_map: false, area_source_kind: nil)
    end

    it '見積の画面に、取り込み元を表示する。手で直すと表示が外れる' do
      post admin_area_imports_path, params: import_params(estimate, work_area)
      get admin_estimate_path(estimate)
      expect(response.body).to include('作業範囲「北側」の実測地積から取り込んだ値')

      patch admin_estimate_path(estimate), params: { estimate: { name: '現場A', area: '9000', area_unit: 'm2' } }
      get admin_estimate_path(estimate)
      expect(response.body).not_to include('取り込んだ値')
    end

    it '面積が空なら取り込まず、作業範囲の画面へ戻してエラーを伝える' do
      post admin_area_imports_path, params: import_params(estimate, work_area, area: '')

      expect(response).to redirect_to(work_area_path(work_area, estimate_id: estimate.id))
      expect(flash[:alert]).to include('面積')
      expect(estimate.reload).to have_attributes(area: 100, area_from_map: false)
    end

    it '他社の見積には取り込めない' do
      other_estimate = Estimate.build_for(other_organization, name: '他社の現場').tap(&:save!)

      post admin_area_imports_path, params: import_params(other_estimate, work_area)

      expect(response).to have_http_status(:not_found)
      expect(other_estimate.reload.area).to be_nil
    end

    it '他社の作業範囲は選べない' do
      other_work_area = create_work_area(other_organization)

      post admin_area_imports_path, params: import_params(estimate, other_work_area)

      expect(response).to have_http_status(:not_found)
      expect(estimate.reload.area).to eq(100)
    end
  end
end
