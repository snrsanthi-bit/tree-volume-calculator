# frozen_string_literal: true

require 'rails_helper'

# 見積の設定: 提出書に載せる自社の情報（社名・住所・電話番号・備考）。
RSpec.describe 'Admin::EstimateSettings 提出書の自社の情報', type: :request do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:admin) do
    User.create!(name: '管理者太郎', email: 'admin@example.com', role: :admin, organization: organization,
                 password: 'password123', password_confirmation: 'password123')
  end

  before { sign_in admin }

  def update_setting(**attributes)
    patch admin_estimate_setting_path, params: { estimate_setting: attributes }
  end

  it '設定の画面に、自社の情報の入力欄がある。社名が空のときの扱いも書いてある' do
    get edit_admin_estimate_setting_path

    expect(response.body).to include('提出書に載せる自社の情報', '社名', '住所', '電話番号', '備考')
    expect(response.body).to include('組織の名前「林業会社A」を使います')
  end

  it '社名・住所・電話番号・備考を保存できる。前後の空白は取り除く' do
    update_setting(issuer_name: ' 株式会社A林業 ', issuer_address: '長野県1-2-3', issuer_phone: '026-000-0000',
                   submission_note: "有効期限は1か月です\n支払いは月末締め")

    expect(response).to redirect_to(edit_admin_estimate_setting_path)
    expect(EstimateSetting.for(organization)).to have_attributes(
      issuer_name: '株式会社A林業', issuer_address: '長野県1-2-3', issuer_phone: '026-000-0000',
      submission_note: "有効期限は1か月です\n支払いは月末締め"
    )
  end

  it '空欄で保存すると、空（nil）になる' do
    update_setting(issuer_name: '株式会社A林業')
    update_setting(issuer_name: '  ', issuer_address: '')

    expect(EstimateSetting.for(organization)).to have_attributes(issuer_name: nil, issuer_address: nil)
  end

  it '長すぎる項目は保存しない' do
    update_setting(issuer_name: 'あ' * 51)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('社名は50文字以内で入力してください')

    update_setting(submission_note: 'あ' * 501)
    expect(response).to have_http_status(:unprocessable_content)
    expect(EstimateSetting.for(organization).issuer_name).to be_nil
  end
end
