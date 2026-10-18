# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkAreas', type: :request do
  def create_another_organization_area
    location = create_another_organization_location
    location.work_areas.create!(
      name: '別会社の作業範囲',
      coordinates: [
        { 'lat' => '35.0', 'lng' => '135.0' },
        { 'lat' => '35.1', 'lng' => '135.1' },
        { 'lat' => '35.2', 'lng' => '135.0' }
      ]
    )
  end
  attr_writer :attr_names

  def create_another_organization_location
    Organization.create!(name: '林業会社B').work_locations.create!(
      name: '別会社の作業地点',
      latitude: 35.0,
      longitude: 135.0
    )
  end

  def sign_in_admin(organization, email:)
    admin = User.create!(
      name: '管理者',
      email: email,
      password: 'password123',
      password_confirmation: 'password123',
      organization: organization,
      role: :admin
    )

    sign_out user
    sign_in admin
  end

  describe 'POST /work_locations/:work_location_id/work_areas' do
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

    let(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end

    let(:coordinates) do
      [
        { lat: 34.3853, lng: 132.4553 },
        { lat: 34.3860, lng: 132.4560 },
        { lat: 34.3865, lng: 132.4550 }
      ]
    end

    let(:expected_coordinates) do
      coordinates.map do |point|
        { 'lat' => point[:lat].to_s, 'lng' => point[:lng].to_s }
      end
    end

    before { sign_in user }

    it '作業範囲と頂点座標を保存できる' do
      sign_in_admin(organization, email: 'admin-work-area-create@example.com')
      expect do
        post work_location_work_areas_path(work_location),
             params: {
               work_area: {
                 name: '北側作業範囲',
                 coordinates: coordinates
               }
             }
      end.to change(WorkArea, :count).by(1)

      saved_work_area = WorkArea.last

      expect(saved_work_area.name).to eq('北側作業範囲')
      expect(saved_work_area.coordinates).to eq(expected_coordinates)
      expect(response).to redirect_to(work_location_work_area_path(work_location, saved_work_area))
    end
  end

  describe 'GET /work_locations/:work_location_id/work_areas' do
    let(:organization) do
      Organization.create!(name: '林業会社A')
    end

    let(:user) do
      User.create!(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization
      )
    end
    let(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end
    let(:coordinates) do
      [
        { lat: 34.3853, lng: 132.4553 },
        { lat: 34.3860, lng: 132.4560 },
        { lat: 34.3865, lng: 132.4550 }
      ]
    end
    let!(:work_area) do
      WorkArea.create!(
        name: '北側作業範囲',
        coordinates: coordinates.map do |point|
          { 'lat' => point[:lat].to_s, 'lng' => point[:lng].to_s }
        end,
        work_location: work_location
      )
    end

    before { sign_in user }

    it '作業地点に紐づく作業範囲を取得できる' do
      get work_location_work_areas_path(work_location)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first).to include(
        'name' => '北側作業範囲',
        'coordinates' => work_area.coordinates
      )
    end

    it '別組織の作業範囲にはアクセスできない' do
      location_b = create_another_organization_location
      area_b = location_b.work_areas.create!(
        name: '別会社の作業範囲',
        coordinates: [
          { 'lat' => '35.0', 'lng' => '135.0' },
          { 'lat' => '35.1', 'lng' => '135.1' },
          { 'lat' => '35.2', 'lng' => '135.0' }
        ]
      )

      get work_location_work_area_path(location_b, area_b)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /work_locations/:work_location_id/work_areas/edit' do
    let(:organization) do
      Organization.create!(name: '林業会社A')
    end

    let(:user) do
      User.create!(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization
      )
    end

    let(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end

    before { sign_in user }

    it '作業地点に紐づく作業範囲の編集画面を表示できる' do
      get edit_work_location_work_areas_path(work_location)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('作業地点A')
    end

    it '別組織の作業地点の編集画面にはアクセスできない' do
      organization_b = Organization.create!(name: '林業会社B')
      location_b = organization_b.work_locations.create!(
        name: '別会社の作業地点',
        latitude: 35.0,
        longitude: 135.0
      )

      get edit_work_location_work_areas_path(location_b)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /work_locations/:work_location_id/work_areas/:id' do
    let(:organization) do
      Organization.create!(name: '林業会社A')
    end

    let(:user) do
      User.create!(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization
      )
    end

    let(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end

    let!(:work_area) do
      WorkArea.create!(
        name: '北側作業範囲',
        coordinates: [
          { 'lat' => '34.3853', 'lng' => '132.4553' },
          { 'lat' => '34.3860', 'lng' => '132.4560' },
          { 'lat' => '34.3865', 'lng' => '132.4550' }
        ],
        work_location: work_location
      )
    end

    before { sign_in user }

    it '保存済みの作業範囲詳細を表示できる' do
      get work_location_work_area_path(work_location, work_area)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('北側作業範囲')
      expect(response.body).to include('作業地点A')
    end

    it '別組織の作業範囲にはアクセスできない' do
      location = create_another_organization_location
      area = location.work_areas.create!(
        name: '別会社の作業範囲',
        coordinates: [
          { 'lat' => '35.0', 'lng' => '135.0' },
          { 'lat' => '35.1', 'lng' => '135.1' },
          { 'lat' => '35.2', 'lng' => '135.0' }
        ]
      )

      get work_location_work_area_path(location, area)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /work_locations/:work_location_id/work_areas/:id' do
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

    let(:work_location) do
      organization.work_locations.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553
      )
    end

    let!(:work_area) do
      work_location.work_areas.create!(
        name: '北側作業範囲',
        coordinates: [
          { 'lat' => '34.3853', 'lng' => '132.4553' },
          { 'lat' => '34.3860', 'lng' => '132.4560' },
          { 'lat' => '34.3865', 'lng' => '132.4550' }
        ]
      )
    end

    let(:updated_coordinates) do
      [
        { lat: 34.3900, lng: 132.4600 },
        { lat: 34.3910, lng: 132.4610 },
        { lat: 34.3920, lng: 132.4590 }
      ]
    end

    before { sign_in user }

    it 'worker は作業範囲を更新できない' do
      original_coordinates = work_area.coordinates

      patch work_location_work_area_path(work_location, work_area),
            params: {
              work_area: {
                coordinates: updated_coordinates
              }
            }

      expect(response).to have_http_status(:forbidden)
      expect(work_area.reload.coordinates).to eq(original_coordinates)
    end

    it '作業範囲の頂点座標を更新して保存できる' do
      sign_in_admin(organization, email: 'admin-area-update@example.com')

      patch work_location_work_area_path(work_location, work_area),
            params: {
              work_area: {
                coordinates: updated_coordinates
              }
            }

      expect(response).to have_http_status(:redirect)
      expect(work_area.reload.coordinates).to eq(
        updated_coordinates.map do |point|
          { 'lat' => point[:lat].to_s, 'lng' => point[:lng].to_s }
        end
      )
    end

    it '別組織の作業範囲は更新できない' do
      another_area = create_another_organization_area
      original_coordinates = another_area.coordinates

      patch work_location_work_area_path(
        another_area.work_location, another_area
      ), params: { work_area: { coordinates: updated_coordinates } }

      expect(response).to have_http_status(:not_found)
      expect(another_area.reload.coordinates).to eq(original_coordinates)
    end
  end
end
