# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkAreas', type: :request do
  let(:organization) { Organization.create!(name: '林業会社A') }

  let(:user) do
    User.create!(
      name: '山田太郎',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      organization: organization
    )
  end

  let(:coordinates) do
    [
      { 'lat' => '34.3853', 'lng' => '132.4553' },
      { 'lat' => '34.3860', 'lng' => '132.4560' },
      { 'lat' => '34.3865', 'lng' => '132.4550' }
    ]
  end

  let(:work_area) do
    organization.work_areas.create!(
      name: '北側作業範囲',
      coordinates: coordinates
    )
  end

  before { sign_in user }

  describe 'POST /work_areas' do
    let(:created_work_area) { WorkArea.last }

    before do
      post work_areas_path,
           params: {
             work_area: {
               name: '北側作業範囲',
               coordinates: coordinates.map do |point|
                 { lat: point['lat'].to_f, lng: point['lng'].to_f }
               end
             }
           }
    end

    it '作業区域を保存できる' do
      expect(response).to redirect_to(work_area_path(created_work_area))
    end

    it '頂点座標を含む作業区域の情報を保存できる' do
      expect(created_work_area.name).to eq('北側作業範囲')
      expect(created_work_area.coordinates).to eq(
        [
          { 'lat' => '34.3853', 'lng' => '132.4553' },
          { 'lat' => '34.386', 'lng' => '132.456' },
          { 'lat' => '34.3865', 'lng' => '132.455' }
        ]
      )
      expect(created_work_area.organization).to eq(organization)
    end
  end

  describe 'GET /work_areas' do
    it '自組織の作業区域を取得できる' do
      area = work_area

      get work_areas_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        a_hash_including(
          'name' => area.name,
          'coordinates' => area.coordinates
        )
      )
    end

    it '他組織の作業区域を一覧に含めない' do
      other_organization = Organization.create!(name: '林業会社B')
      other_organization.work_areas.create!(
        name: '別会社の作業区域',
        coordinates: coordinates
      )

      get work_areas_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('name')).not_to include('別会社の作業区域')
    end
  end

  describe 'GET /work_areas/:id' do
    it '保存済みの作業区域詳細を表示できる' do
      area = work_area

      get work_area_path(area)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('北側作業範囲')
    end

    it '別組織の作業区域にはアクセスできない' do
      other_organization = Organization.create!(name: '林業会社B')
      other_area = other_organization.work_areas.create!(
        name: '別会社の作業区域',
        coordinates: coordinates
      )

      get work_area_path(other_area)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /work_areas/:id/edit' do
    it '編集画面を表示できる' do
      area = work_area

      get edit_work_area_path(area)

      expect(response).to have_http_status(:ok)
    end
  end
end
