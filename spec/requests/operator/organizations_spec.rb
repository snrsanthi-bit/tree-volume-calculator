# frozen_string_literal: true

require 'rails_helper'

# 運営(operator)は、組織の管理と、管理者・作業者アカウントの作成ができる。
RSpec.describe 'Operator::Organizations', type: :request do
  def build_user(organization, email, role, name: '山田太郎')
    User.create!(
      name: name, email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  def organization_params(overrides = {})
    { organization: { name: '新しい林業会社' }, admin: { name: '新任管理者', email: 'new-admin@example.com' } }
      .merge(overrides)
  end

  let(:operations) { Organization.create!(name: '運営') }
  let(:company) { Organization.create!(name: '林業会社A') }
  let(:operator) { build_user(operations, 'operator@example.com', :operator, name: '運営担当') }

  describe '運営以外は使えない' do
    it '未ログインならログイン画面へ移動する' do
      get operator_organizations_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it '管理者・作業者は 403 で、組織もアカウントも作れない' do
      %i[admin worker].each do |role|
        sign_in build_user(company, "#{role}@example.com", role)

        get operator_organizations_path
        expect(response).to have_http_status(:forbidden)

        expect { post operator_organizations_path, params: organization_params }.not_to change(Organization, :count)
        expect(response).to have_http_status(:forbidden)

        expect do
          post operator_organization_users_path(company), params: { user: { name: 'x', email: 'x@example.com' } }
        end.not_to change(User, :count)
        sign_out :user
      end
    end
  end

  describe '運営: 組織の管理' do
    before { sign_in operator }

    it '全組織を一覧できる' do
      company

      get operator_organizations_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('林業会社A')
    end

    it '組織と最初の管理者を作成し、招待URLを一度だけ渡す' do
      expect { post operator_organizations_path, params: organization_params }
        .to change(Organization, :count).by(1).and change(User, :count).by(1)

      organization = Organization.find_by!(name: '新しい林業会社')
      admin = organization.users.first

      expect(response).to redirect_to(operator_organization_path(organization))
      expect(admin).to be_admin
      expect(admin.email).to eq('new-admin@example.com')
      expect(flash[:invitation]['url']).to include('/users/password/edit?reset_password_token=')
    end

    it '組織名や管理者の情報が足りなければ何も作らない' do
      expect { post operator_organizations_path, params: organization_params(organization: { name: '' }) }
        .not_to change(Organization, :count)
      expect(response).to have_http_status(:unprocessable_content)

      bad_admin = { admin: { name: '', email: 'x@example.com' } }
      expect { post operator_organizations_path, params: organization_params(bad_admin) }
        .not_to change(User, :count)
      expect(Organization.where(name: '新しい林業会社')).to be_empty
    end

    it '組織名を変更できる' do
      patch operator_organization_path(company), params: { organization: { name: '改名した会社' } }

      expect(response).to redirect_to(operator_organization_path(company))
      expect(company.reload.name).to eq('改名した会社')
    end

    it '組織の詳細で、所属ユーザーを確認できる' do
      build_user(company, 'worker@example.com', :worker, name: '作業者花子')

      get operator_organization_path(company)

      expect(response.body).to include('作業者花子')
    end
  end

  describe '運営: アカウントの作成と招待' do
    before { sign_in operator }

    def user_params(overrides = {})
      { user: { name: '新人', email: 'new@example.com', role: 'worker' }.merge(overrides) }
    end

    it '指定した組織に、管理者または作業者を作成できる' do
      post operator_organization_users_path(company), params: user_params(role: 'admin')
      expect(User.find_by!(email: 'new@example.com')).to be_admin

      post operator_organization_users_path(company), params: user_params(email: 'w@example.com')
      created = User.find_by!(email: 'w@example.com')

      expect(created).to be_worker
      expect(created.organization).to eq(company)
      expect(flash[:invitation]['url']).to include('reset_password_token=')
    end

    it '運営アカウントは画面から作れない（権限を指定しても作業者になる）' do
      post operator_organization_users_path(company), params: user_params(role: 'operator')

      expect(User.find_by!(email: 'new@example.com')).to be_worker
    end

    it '招待URLを再発行でき、前のURLは使えなくなる' do
      worker = build_user(company, 'worker@example.com', :worker)
      old_token = worker.issue_invitation_token!

      post invitation_operator_organization_user_path(company, worker)

      expect(response).to redirect_to(operator_organization_path(company))
      expect(User.with_reset_password_token(old_token)).to be_nil
      expect(flash[:invitation]['email']).to eq('worker@example.com')
    end

    it '別の組織のユーザーを、URLの組織経由で操作することはできない' do
      other = build_user(Organization.create!(name: '林業会社B'), 'other@example.com', :worker)

      post invitation_operator_organization_user_path(company, other)

      expect(response).to have_http_status(:not_found)
    end

    it '運営ユーザーの招待URLは再発行できない' do
      post invitation_operator_organization_user_path(operations, operator)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'メニュー' do
    it '運営には「組織の管理」が表示され、「作業範囲一覧」は表示されない' do
      sign_in operator

      get root_path

      expect(response.body).to include(operator_organizations_path)
      expect(response.body).not_to include(work_areas_path)
    end

    it '管理者・作業者には「組織の管理」が表示されない' do
      sign_in build_user(company, 'admin@example.com', :admin)

      get root_path

      expect(response.body).not_to include(operator_organizations_path)
    end
  end
end
