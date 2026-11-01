# frozen_string_literal: true

require 'rails_helper'

# 区分（伐採費・整理費など）は、会社の管理者(admin)だけが、自社の分だけ扱える。
RSpec.describe 'Admin::CostCategories', type: :request do
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
  let(:category) { organization.cost_categories.create!(name: '伐採費') }

  describe '未認証・作業者・運営' do
    it '未認証ならログイン画面へ移動し、区分も作れない' do
      get admin_cost_categories_path
      expect(response).to redirect_to(new_user_session_path)

      expect { post admin_cost_categories_path, params: { cost_category: { name: '伐採費' } } }
        .not_to change(CostCategory, :count)
    end

    it '作業者は一覧を開けず、区分も作れない・消せない' do
      category
      sign_in worker

      get admin_cost_categories_path
      expect(response).to have_http_status(:forbidden)

      expect { post admin_cost_categories_path, params: { cost_category: { name: '整理費' } } }
        .not_to change(CostCategory, :count)
      expect { delete admin_cost_category_path(category) }.not_to change(CostCategory, :count)
    end

    it '運営(operator)も使えない' do
      sign_in build_user(organization, 'operator@example.com', :operator)

      get admin_cost_categories_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '管理者' do
    before { sign_in admin }

    it '自社の区分だけを表示する' do
      category
      other_organization.cost_categories.create!(name: '他社の区分')

      get admin_cost_categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('伐採費')
      expect(response.body).not_to include('他社の区分')
    end

    it '区分を追加できる' do
      expect { post admin_cost_categories_path, params: { cost_category: { name: '伐採費' } } }
        .to change(organization.cost_categories, :count).by(1)

      expect(response).to redirect_to(admin_cost_categories_path)
    end

    it '名前が空・重複のときは追加せず、エラーを表示する' do
      category

      expect { post admin_cost_categories_path, params: { cost_category: { name: '' } } }
        .not_to change(CostCategory, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('を入力してください')

      expect { post admin_cost_categories_path, params: { cost_category: { name: '伐採費' } } }
        .not_to change(CostCategory, :count)
      expect(response.body).to include('すでに使われています')
    end

    it '会社を指定して、他社に区分を作ることはできない' do
      post admin_cost_categories_path,
           params: { cost_category: { name: '不正', organization_id: other_organization.id } }

      expect(other_organization.cost_categories.count).to eq(0)
      expect(organization.cost_categories.pluck(:name)).to eq(['不正'])
    end

    it '区分の名前を変えられる' do
      patch admin_cost_category_path(category), params: { cost_category: { name: '伐採・搬出費' } }

      expect(response).to redirect_to(admin_cost_categories_path)
      expect(category.reload.name).to eq('伐採・搬出費')
    end

    it '使われていない区分は削除できる' do
      category

      expect { delete admin_cost_category_path(category) }.to change(CostCategory, :count).by(-1)
      expect(response).to redirect_to(admin_cost_categories_path)
    end

    it '単価マスタの項目が使っている区分は削除できず、理由を表示する' do
      category.cost_items.create!(organization: organization, name: '伐採 人工', unit: '人日', unit_price: 28_000)

      expect { delete admin_cost_category_path(category) }.not_to change(CostCategory, :count)
      expect(response).to redirect_to(admin_cost_categories_path)
      expect(flash[:alert]).to include('使われている')
    end
  end

  describe '他社の区分' do
    it '編集・更新・削除のどれも404になり、変更されない' do
      other = other_organization.cost_categories.create!(name: '他社の区分')

      sign_in admin
      get edit_admin_cost_category_path(other)
      expect(response).to have_http_status(:not_found)

      sign_in admin
      patch admin_cost_category_path(other), params: { cost_category: { name: '乗っ取り' } }
      expect(response).to have_http_status(:not_found)

      sign_in admin
      delete admin_cost_category_path(other)
      expect(response).to have_http_status(:not_found)
      expect(other.reload.name).to eq('他社の区分')
    end
  end
end
