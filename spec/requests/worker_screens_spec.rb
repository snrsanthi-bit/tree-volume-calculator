# frozen_string_literal: true

require 'rails_helper'

# 作業者が見る画面（計算・作業範囲）に、見積の金額・原価・利益率は出ない。
RSpec.describe '作業者の画面と見積の金額', type: :request do
  include EstimateSampleHelpers

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:worker) do
    User.create!(name: '作業者次郎', email: 'worker@example.com', role: :worker, organization: organization,
                 password: 'password123', password_confirmation: 'password123')
  end
  let(:work_area) do
    organization.work_areas.create!(
      name: '北側作業範囲',
      coordinates: [{ 'lat' => '34.3853', 'lng' => '132.4553' }, { 'lat' => '34.3860', 'lng' => '132.4560' },
                    { 'lat' => '34.3865', 'lng' => '132.4550' }]
    )
  end

  # 見積に関係する言葉と金額（サンプルの見積: 売価 929,000円・原価 649,950円・利益 279,050円）
  def estimate_words
    %w[売価 原価 利益 諸経費 消費税 見積 929,000 649,950 279,050 1,021,900]
  end

  def worker_paths
    [root_path, area_path, work_areas_path, work_area_path(work_area), new_work_area_path,
     edit_work_area_path(work_area)]
  end

  it '見積がある会社でも、作業者の画面に、見積の言葉も金額も出ない' do
    create_sample_estimate(organization)
    sign_in worker

    aggregate_failures do
      worker_paths.each do |path|
        get path

        estimate_words.each { |word| expect(response.body).not_to include(word), "#{path} に「#{word}」が出ている" }
      end
    end
  end

  it '作業者が見積に関する画面を開くと、権限がない画面になる（金額は出ない）' do
    estimate = create_sample_estimate(organization)
    sign_in worker

    get admin_estimate_path(estimate)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).not_to include('929,000', '649,950', '279,050')
  end
end
