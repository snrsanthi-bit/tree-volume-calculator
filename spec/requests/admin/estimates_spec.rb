# frozen_string_literal: true

require 'rails_helper'

# 見積は、会社の管理者(admin)だけが、自社の分だけ扱える。
RSpec.describe 'Admin::Estimates', type: :request do
  include EstimateSampleHelpers

  def build_user(organization, email, role, name: '山田太郎')
    User.create!(
      name: name, email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:admin) { build_user(organization, 'admin@example.com', :admin, name: '管理者太郎') }
  let(:worker) { build_user(organization, 'worker@example.com', :worker) }
  let(:estimate) { create_sample_estimate(organization) }

  describe '未認証・作業者・運営' do
    it '未認証ならログイン画面へ移動し、見積も作れない' do
      get admin_estimates_path
      expect(response).to redirect_to(new_user_session_path)

      expect { post admin_estimates_path, params: { estimate: { name: '現場A' } } }
        .not_to change(Estimate, :count)
    end

    it '作業者は見積を見られず、作れない・消せない' do
      estimate
      sign_in worker

      get admin_estimates_path
      expect(response).to have_http_status(:forbidden)
      get admin_estimate_path(estimate)
      expect(response).to have_http_status(:forbidden)

      expect { post admin_estimates_path, params: { estimate: { name: '現場B' } } }.not_to change(Estimate, :count)
      expect { delete admin_estimate_path(estimate) }.not_to change(Estimate, :count)
    end

    it '運営(operator)も使えない' do
      sign_in build_user(organization, 'operator@example.com', :operator)

      get admin_estimates_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '管理者' do
    before { sign_in admin }

    it '自社の見積だけを一覧に表示する' do
      estimate
      create_sample_estimate(other_organization, name: '他社の現場')

      get admin_estimates_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('北側作業範囲')
      expect(response.body).not_to include('他社の現場')
    end

    it '新規作成の画面を開ける' do
      get new_admin_estimate_path

      expect(response).to have_http_status(:ok)
    end

    it '見積を作ると、その時点の見積の設定がコピーされ、見積の画面へ移動する' do
      EstimateSetting.for(organization).update!(overhead_rate: 8, margin_rate: 25)

      expect { post admin_estimates_path, params: { estimate: { name: '現場A', area: '８，４２０' } } }
        .to change(organization.estimates, :count).by(1)

      created = organization.estimates.last
      expect(response).to redirect_to(admin_estimate_path(created))
      expect(created).to have_attributes(name: '現場A', area: 8420, overhead_rate: 8, margin_rate: 25)
    end

    it '面積は空でも作れる' do
      expect { post admin_estimates_path, params: { estimate: { name: '現場A', area: '' } } }
        .to change(Estimate, :count).by(1)
    end

    it '現場名が空・面積がマイナスなら作らず、エラーを表示する' do
      expect { post admin_estimates_path, params: { estimate: { name: '', area: '-5' } } }
        .not_to change(Estimate, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('現場名を入力してください')
      expect(response.body).to include('面積は0より大きい値にしてください')
    end

    it '会社や設定の値は、パラメータで上書きできない' do
      post admin_estimates_path,
           params: { estimate: { name: '現場A', organization_id: other_organization.id, margin_rate: 1 } }

      created = Estimate.find_by!(name: '現場A')
      expect(created.organization).to eq(organization)
      expect(created.margin_rate).to eq(30)
    end

    it '見積の画面に、明細と集計（売価）が出る' do
      get admin_estimate_path(estimate)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('バックホウ')
      expect(response.body).to include('929,000')
    end

    it '現場名と面積を変更できる。見積の設定は変わらない' do
      patch admin_estimate_path(estimate), params: { estimate: { name: '南側', area: '100', margin_rate: 5 } }

      expect(response).to redirect_to(admin_estimate_path(estimate))
      expect(estimate.reload).to have_attributes(name: '南側', area: 100, margin_rate: 30)
    end

    it '変更が不正なら、更新せずエラーを表示する' do
      patch admin_estimate_path(estimate), params: { estimate: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(estimate.reload.name).to eq('北側作業範囲')
    end

    it '見積を削除すると、明細も消える' do
      estimate

      expect { delete admin_estimate_path(estimate) }.to change(Estimate, :count).by(-1)
                                                                                 .and change(EstimateLine,
                                                                                             :count).by(-5)
      expect(response).to redirect_to(admin_estimates_path)
      expect(response).to have_http_status(:see_other)
    end

    it '他社の見積は、見る・変える・消すがすべて404' do
      other = create_sample_estimate(other_organization, name: '他社の現場')

      get admin_estimate_path(other)
      expect(response).to have_http_status(:not_found)

      sign_in admin
      patch admin_estimate_path(other), params: { estimate: { name: '乗っ取り' } }
      expect(response).to have_http_status(:not_found)

      sign_in admin
      expect { delete admin_estimate_path(other) }.not_to change(Estimate, :count)
      expect(other.reload.name).to eq('他社の現場')
    end
  end

  describe '受け入れ条件' do
    before { sign_in admin }

    it '単価マスタの単価を変えても、作成済みの見積の売価は変わらない' do
      estimate
      machine = organization.cost_categories.find_by!(name: '機械費')
      item = machine.cost_items.create!(organization: organization, name: 'バックホウ', unit: '日', unit_price: 48_000)

      item.update!(unit_price: 480_000)
      get admin_estimate_path(estimate)

      expect(response.body).to include('929,000')
    end

    it '見積の設定の利益率を変えても、作成済みの見積の売価は変わらない' do
      estimate
      EstimateSetting.for(organization).update!(margin_rate: 50)

      get admin_estimate_path(estimate)

      expect(response.body).to include('929,000')
    end
  end
end
