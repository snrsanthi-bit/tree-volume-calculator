# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkAreas', type: :request do
  # 点(points)と線(lines)だけを保存する。三角形は保存せず導出する。
  def survey_points
    [
      { 'id' => 'p-1', 'lat' => 34.3853, 'lng' => 132.4553, 'origin' => 'input' },
      { 'id' => 'p-2', 'lat' => 34.3860, 'lng' => 132.4560, 'origin' => 'input' },
      { 'id' => 'p-3', 'lat' => 34.3865, 'lng' => 132.4550, 'origin' => 'input' }
    ]
  end

  def survey_lines
    [
      survey_line('l-1', 'p-1', 'p-2', 100.5),
      survey_line('l-2', 'p-2', 'p-3', 120.3),
      survey_line('l-3', 'p-3', 'p-1', 90.2)
    ]
  end

  def survey_line(id, from, to, estimated)
    {
      'id' => id, 'from' => from, 'to' => to, 'origin' => 'proposed',
      'estimated_length' => estimated, 'measured_length' => nil
    }
  end

  def expected_survey_data
    { 'version' => 2, 'points' => survey_points, 'lines' => survey_lines }
  end

  def work_area_params_with_survey_data(data = expected_survey_data)
    { work_area: { name: '測量データ付き作業範囲', coordinates: coordinates, survey_data: data.to_json } }
  end

  let(:organization) { Organization.create!(name: '林業会社A') }

  let(:user) do
    User.create!(
      name: '山田太郎',
      email: 'user@example.com',
      role: :admin,
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
    organization.work_areas.create!(name: '北側作業範囲', coordinates: coordinates)
  end

  before { sign_in user }

  describe 'POST /work_areas' do
    let(:created_work_area) { WorkArea.last }

    before do
      post work_areas_path,
           params: {
             work_area: {
               name: '北側作業範囲',
               coordinates: coordinates.map { |point| { lat: point['lat'].to_f, lng: point['lng'].to_f } }
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

    it '点と線の測量データを保存できる' do
      post work_areas_path, params: work_area_params_with_survey_data

      expect(WorkArea.last.survey_data).to eq(expected_survey_data)
    end

    it '存在しない点を参照する線を含むデータは保存できない' do
      data = expected_survey_data
      data['lines'] << survey_line('l-9', 'p-1', 'p-404', 10)

      expect do
        post work_areas_path, params: work_area_params_with_survey_data(data)
      end.not_to change(WorkArea, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '長さが負の線を含むデータは保存できない' do
      data = expected_survey_data
      data['lines'][0]['measured_length'] = -1

      expect do
        post work_areas_path, params: work_area_params_with_survey_data(data)
      end.not_to change(WorkArea, :count)
    end
  end

  describe 'PATCH /work_areas/:id' do
    it '補助点と補助線を含む測量データを更新できる' do
      area = work_area
      data = expected_survey_data
      data['points'] << { 'id' => 'p-4', 'lat' => 34.3859, 'lng' => 132.4554, 'origin' => 'worker' }
      data['lines'] << { 'id' => 'l-4', 'from' => 'p-4', 'to' => 'p-1', 'origin' => 'worker',
                         'estimated_length' => 40.0, 'measured_length' => nil }

      patch work_area_path(area), params: work_area_params_with_survey_data(data)

      saved = area.reload.survey_data
      expect(saved['points'].pluck('origin')).to include('worker')
      expect(saved['lines'].last).to include('origin' => 'worker', 'from' => 'p-4', 'to' => 'p-1')
    end
  end

  describe 'PATCH /work_areas/:id/measurements' do
    let(:area) do
      organization.work_areas.create!(name: '北側作業範囲', coordinates: coordinates, survey_data: expected_survey_data)
    end

    it '実測値だけを保存し、点・線の構造は変えない' do
      patch measurements_work_area_path(area), params: { measurements: { 'l-1' => '98.7', 'l-2' => '' } }

      expect(response).to have_http_status(:ok)
      saved = area.reload.survey_data
      expect(saved['lines'].find { |l| l['id'] == 'l-1' }).to include('measured_length' => 98.7,
                                                                      'estimated_length' => 100.5)
      expect(saved['lines'].find { |l| l['id'] == 'l-2' }['measured_length']).to be_nil
      expect(saved['points']).to eq(survey_points)
      expect(saved['lines'].pluck('id')).to eq(%w[l-1 l-2 l-3])
    end

    it '数値でない値は拒否し、データを変更しない' do
      patch measurements_work_area_path(area), params: { measurements: { 'l-1' => 'abc' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(area.reload.survey_data).to eq(expected_survey_data)
    end

    it '0以下の値は拒否する' do
      patch measurements_work_area_path(area), params: { measurements: { 'l-1' => '0' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '別組織の作業区域には保存できない' do
      other = Organization.create!(name: '林業会社B').work_areas.create!(
        name: '別会社', coordinates: coordinates, survey_data: expected_survey_data
      )

      patch measurements_work_area_path(other), params: { measurements: { 'l-1' => '50' } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /work_areas' do
    it '自組織の作業区域を取得できる' do
      area = work_area

      get work_areas_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        a_hash_including('name' => area.name, 'coordinates' => area.coordinates)
      )
    end

    it '他組織の作業区域を一覧に含めない' do
      Organization.create!(name: '林業会社B').work_areas.create!(name: '別会社の作業区域', coordinates: coordinates)

      get work_areas_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('name')).not_to include('別会社の作業区域')
    end
  end

  describe 'GET /work_areas/:id' do
    it '保存済みの作業区域詳細を表示できる' do
      get work_area_path(work_area)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('北側作業範囲')
    end

    it '別組織の作業区域にはアクセスできない' do
      other_area = Organization.create!(name: '林業会社B').work_areas.create!(
        name: '別会社の作業区域', coordinates: coordinates
      )

      get work_area_path(other_area)

      expect(response).to have_http_status(:not_found)
    end

    it '保存済みの測量データを詳細画面に渡す' do
      area = work_area
      area.update!(survey_data: expected_survey_data)

      get work_area_path(area)

      document = response.parsed_body
      survey_data = JSON.parse(document.at_css('#triangle-list')['data-survey-data'])

      expect(survey_data).to eq(expected_survey_data)
    end
  end

  describe 'GET /work_areas/:id/edit' do
    it '編集画面を表示できる' do
      get edit_work_area_path(work_area)

      expect(response).to have_http_status(:ok)
    end
  end

  describe '権限ごとの操作' do
    def build_member(role)
      User.create!(name: "#{role}ユーザー", email: "#{role}@example.com", role: role, organization: organization,
                   password: 'password123', password_confirmation: 'password123')
    end

    let(:area_with_lines) do
      work_area.tap { |area| area.update!(survey_data: expected_survey_data) }
    end

    it '作業者は一覧・詳細を閲覧できる' do
      sign_in build_member(:worker)

      get work_areas_path
      expect(response).to have_http_status(:ok)

      get work_area_path(work_area)
      expect(response).to have_http_status(:ok)
    end

    it '作業者は現場で測った実測値を入力して保存できる' do
      sign_in build_member(:worker)

      patch measurements_work_area_path(area_with_lines), params: { measurements: { 'l-1' => '98.7' } }

      expect(response).to have_http_status(:ok)
      expect(area_with_lines.reload.survey_data['lines'].first['measured_length']).to eq(98.7)
    end

    it '作業者は作業範囲を新規作成・編集・更新できない' do
      sign_in build_member(:worker)

      get new_work_area_path
      expect(response).to have_http_status(:forbidden)

      expect { post work_areas_path, params: work_area_params_with_survey_data }.not_to change(WorkArea, :count)
      expect(response).to have_http_status(:forbidden)

      get edit_work_area_path(work_area)
      expect(response).to have_http_status(:forbidden)

      patch work_area_path(work_area), params: { work_area: { name: '書き換え', coordinates: coordinates } }
      expect(response).to have_http_status(:forbidden)
      expect(work_area.reload.name).to eq('北側作業範囲')
    end

    it '作業者の画面には、新規作成・編集の導線が表示されない' do
      sign_in build_member(:worker)
      area = work_area # 一覧に載せるため、先に作成しておく

      get work_areas_path
      expect(response.body).to include(area.name)
      expect(response.body).not_to include(new_work_area_path, edit_work_area_path(area))

      get work_area_path(area)
      expect(response.body).not_to include(edit_work_area_path(area))
    end

    it '管理者の画面には、新規作成・編集の導線が表示される' do
      area = work_area # 一覧に載せるため、先に作成しておく

      get work_areas_path

      expect(response.body).to include(new_work_area_path, edit_work_area_path(area))
    end

    it '運営(operator)は作業範囲を扱わない' do
      sign_in build_member(:operator)

      get work_areas_path
      expect(response).to have_http_status(:forbidden)

      get new_work_area_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
