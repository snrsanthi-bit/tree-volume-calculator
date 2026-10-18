# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkLocations', type: :request do
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

  def create_another_organization_location
    organization = Organization.create!(name: '林業会社B')
    organization.work_locations.create!(
      name: '別会社の作業地点',
      latitude: 35.0,
      longitude: 135.0
    )
  end

  describe 'POST /work_locations' do
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

    let(:valid_params) do
      {
        work_location: {
          name: '作業地点A',
          latitude: 34.3853,
          longitude: 132.4553
        }
      }
    end

    before do
      sign_in user
    end

    it 'ログインユーザーの所属組織に地点情報を保存できる' do
      admin = User.create!(
        name: '管理者',
        email: 'admin-create@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization,
        role: :admin
      )

      sign_out user
      sign_in admin
      expect do
        post work_locations_path, params: valid_params
      end.to change(WorkLocation, :count).by(1)

      work_location = WorkLocation.last
      expect(work_location.organization).to eq(organization)
    end

    it '登録成功時にリダイレクトする' do
      admin = User.create!(
        name: '管理者',
        email: 'admin-create@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization,
        role: :admin
      )

      sign_out user
      sign_in admin
      post work_locations_path, params: valid_params

      expect(response).to have_http_status(:redirect)
    end

    it '緯度が範囲外なら保存されない' do
      invalid_params = valid_params.deep_dup
      invalid_params[:work_location][:latitude] = 91

      expect do
        post work_locations_path, params: invalid_params
      end.not_to change(WorkLocation, :count)
    end

    it '未ログインの場合は登録されず、ログイン画面へリダイレクトする' do
      expect do
        sign_out user
        post work_locations_path, params: valid_params
      end.not_to change(WorkLocation, :count)

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'worker は作業地点を登録できない' do
      expect do
        post work_locations_path, params: valid_params
      end.not_to change(WorkLocation, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /work_locations/:id' do
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

    let!(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end

    before { sign_in user }

    it '所属組織の作業地点を表示する' do
      get work_location_path(work_location)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('作業地点A')
    end

    it '別組織の作業地点は表示できない' do
      another_organization = Organization.create!(name: '林業会社B')
      another_location = WorkLocation.create!(
        name: '別会社の作業地点',
        latitude: 35.0,
        longitude: 135.0,
        organization: another_organization
      )

      get work_location_path(another_location)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /work_locations/:id' do
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

    let!(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end

    before { sign_in user }

    it '作業地点の緯度・経度を更新して保存できる' do
      sign_in_admin(organization, email: 'admin-update@example.com')

      patch work_location_path(work_location), params: {
        work_location: {
          latitude: 34.3900,
          longitude: 132.4600
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(work_location.reload.latitude).to eq(BigDecimal('34.3900'))
      expect(work_location.longitude).to eq(BigDecimal('132.4600'))
    end

    it '緯度が範囲外なら更新されない' do
      patch work_location_path(work_location), params: {
        work_location: {
          latitude: 91,
          longitude: 132.4600
        }
      }

      expect(work_location.reload.latitude).to eq(BigDecimal('34.3853'))
      expect(work_location.longitude).to eq(BigDecimal('132.4553'))
    end

    it '別組織の作業地点は更新できない' do
      another_location = create_another_organization_location

      patch work_location_path(another_location), params: {
        work_location: {
          latitude: 35.1,
          longitude: 135.1
        }
      }

      expect(response).to have_http_status(:not_found)
      expect(another_location.reload.latitude).to eq(BigDecimal('35.0'))
      expect(another_location.longitude).to eq(BigDecimal('135.0'))
    end

    it 'worker は作業地点を更新できない' do
      patch work_location_path(work_location), params: {
        work_location: {
          latitude: 34.3900,
          longitude: 132.4600
        }
      }

      expect(response).to have_http_status(:forbidden)
      expect(work_location.reload.latitude).to eq(BigDecimal('34.3853'))
      expect(work_location.longitude).to eq(BigDecimal('132.4553'))
    end

    it 'admin は作業地点を更新できる' do
      sign_in_admin(organization, email: 'admin@example.com')

      patch work_location_path(work_location), params: {
        work_location: {
          latitude: 34.3900,
          longitude: 132.4600
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(work_location.reload.latitude).to eq(BigDecimal('34.3900'))
      expect(work_location.longitude).to eq(BigDecimal('132.4600'))
    end
  end
end
