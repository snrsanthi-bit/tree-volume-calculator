# frozen_string_literal: true

require 'rails_helper'

# 見積を先に作る場合も、作業範囲を先に作る場合も、地積を見積に取り込める導線。
RSpec.describe 'Admin::Estimates 作業範囲からの導線', type: :request do
  def build_user(organization, email, role)
    User.create!(
      name: '山田太郎', email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  def create_work_area(owner, name)
    owner.work_areas.create!(name: name, coordinates: [[35.0, 139.0], [35.0, 139.001], [35.001, 139.0]])
  end

  def work_area_params
    { work_area: { name: '新しい範囲', coordinates: [[35.0, 139.0], [35.0, 139.001], [35.001, 139.0]].to_json,
                   survey_data: '{}' } }
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:estimate) { Estimate.build_for(organization, name: '現場A').tap(&:save!) }

  before do
    sign_in build_user(organization, 'admin@example.com', :admin)
    create_work_area(organization, '北側')
    create_work_area(other_organization, '他社の範囲')
  end

  describe '見積を先に作る' do
    it '新規の画面に、自社の作業範囲への入口と、作業範囲を新しく作る入口がある' do
      get new_admin_estimate_path

      expect(response.body).to include('「北側」の地積を確認して取り込む').and include('作業範囲を地図で新しく作る')
      expect(response.body).to include('estimate_id=new')
      expect(response.body).not_to include('他社の範囲')
    end

    it '見積の画面からは、その見積を取り込み先にして作業範囲へ進める' do
      get admin_estimate_path(estimate)

      expect(response.body).to include("estimate_id=#{estimate.id}")
    end

    it '新規作成が失敗しても、画面が表示される' do
      post admin_estimates_path, params: { estimate: { name: '', area: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('「北側」の地積を確認して取り込む')
    end
  end

  describe '作業範囲の保存後' do
    it '見積から来たときは、保存後に作業範囲の画面へ移り、その見積を取り込み先に選んでおく' do
      get new_work_area_path(estimate_id: estimate.id)
      expect(response.body).to include(%(id="estimate_id" value="#{estimate.id}"))
      post work_areas_path, params: work_area_params.merge(estimate_id: estimate.id)

      created = WorkArea.find_by!(name: '新しい範囲')
      expect(response).to redirect_to(work_area_path(created, estimate_id: estimate.id))

      get work_area_path(created, estimate_id: estimate.id)
      expect(response.body).to include(%(selected="selected" value="#{estimate.id}"))
    end

    it '新しい見積を作る導線なら、取り込み先は「新しい見積を作る」が選ばれる' do
      get new_work_area_path(estimate_id: 'new')
      post work_areas_path, params: work_area_params.merge(estimate_id: 'new')

      created = WorkArea.find_by!(name: '新しい範囲')
      expect(response).to redirect_to(work_area_path(created, estimate_id: 'new'))

      get work_area_path(created, estimate_id: 'new')
      expect(response.body).to include('selected="selected" value=""').and include('新しい見積を作る')
    end

    it '見積の画面を経由しないときは、これまで通り作業範囲の画面へ移る' do
      get new_work_area_path
      expect(response.body).not_to include('name="estimate_id"')
      post work_areas_path, params: work_area_params

      expect(response).to redirect_to(work_area_path(WorkArea.find_by!(name: '新しい範囲')))
    end

    it '別のタブで別の見積から作業範囲を作っても、それぞれの見積に戻る' do
      other_estimate = Estimate.build_for(organization, name: '現場B').tap(&:save!)
      get new_work_area_path(estimate_id: estimate.id)
      get new_work_area_path(estimate_id: other_estimate.id)

      post work_areas_path, params: work_area_params.merge(estimate_id: estimate.id)

      expect(response).to redirect_to(work_area_path(WorkArea.find_by!(name: '新しい範囲'), estimate_id: estimate.id))
    end

    it '見積の指定が不正な値なら、無視する' do
      post work_areas_path, params: work_area_params.merge(estimate_id: '1; drop')

      expect(response).to redirect_to(work_area_path(WorkArea.find_by!(name: '新しい範囲')))
    end

    it '保存に失敗して画面を出し直しても、取り込み先の見積を引き継ぐ' do
      post work_areas_path, params: { work_area: { name: '', coordinates: '[]', survey_data: '{}' },
                                      estimate_id: estimate.id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(id="estimate_id" value="#{estimate.id}"))
    end
  end
end
