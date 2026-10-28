# frozen_string_literal: true

require 'rails_helper'

# 管理者(admin)は、自社の作業者(worker)だけを管理できる。
# 管理者アカウントの作成・権限の変更・他社の操作はできない。
RSpec.describe 'Admin::Users', type: :request do
  def build_user(organization, email, role, name: '山田太郎')
    User.create!(
      name: name, email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  def user_params(overrides = {})
    { user: { name: '新人作業員', email: 'new@example.com' }.merge(overrides) }
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:admin) { build_user(organization, 'admin@example.com', :admin, name: '管理者太郎') }
  let(:worker) { build_user(organization, 'worker@example.com', :worker, name: '作業者花子') }

  describe '未認証ユーザー' do
    it '管理画面にアクセスするとログイン画面へ移動する' do
      get admin_users_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'ユーザーを作成できない' do
      expect { post admin_users_path, params: user_params }.not_to change(User, :count)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe '作業者・運営は管理者の画面を使えない' do
    it '作業者は一覧・追加・編集画面を開けず、ユーザーも作成できない' do
      sign_in worker

      get admin_users_path
      expect(response).to have_http_status(:forbidden)
      get new_admin_user_path
      expect(response).to have_http_status(:forbidden)
      get edit_admin_user_path(worker)
      expect(response).to have_http_status(:forbidden)

      expect { post admin_users_path, params: user_params }.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it '運営(operator)も管理者の画面は使えない（運営は運営用の画面で対応する）' do
      sign_in build_user(organization, 'operator@example.com', :operator)

      get admin_users_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '管理者: 一覧' do
    before { sign_in admin }

    it '自社の作業者だけを表示し、管理者・運営・他社のユーザーは表示しない' do
      worker
      build_user(other_organization, 'other@example.com', :worker, name: '他社の人')
      build_user(organization, 'operator@example.com', :operator, name: '運営の人')
      build_user(organization, 'admin2@example.com', :admin, name: '別の管理者')

      get admin_users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('作業者花子')
      # 画面右上にログイン中の名前(管理者太郎)が出るので、一覧に出ないことは別の管理者で確かめる
      expect(response.body).not_to include('他社の人', '運営の人', '別の管理者')
    end
  end

  describe '管理者: 作業者の作成' do
    before { sign_in admin }

    it '自社の作業者を作成し、招待URLを一度だけ渡す' do
      expect { post admin_users_path, params: user_params }.to change(User, :count).by(1)

      created = User.find_by!(email: 'new@example.com')
      invitation = flash[:invitation]

      expect(response).to redirect_to(admin_users_path)
      expect(created.organization).to eq(organization)
      expect(created).to be_worker
      expect(invitation['email']).to eq('new@example.com')
      expect(invitation['url']).to include('/users/password/edit?reset_password_token=')
    end

    it '管理者は作成したユーザーのパスワードを知らない（初期パスワードを表示しない）' do
      post admin_users_path, params: user_params
      follow_redirect!

      expect(response.body).to include('招待URL')
      expect(response.body).not_to include('初期パスワード')
    end

    it '管理者アカウントは作成できない（権限を指定しても作業者になる）' do
      post admin_users_path, params: user_params(role: 'admin')
      expect(User.find_by!(email: 'new@example.com')).to be_worker

      post admin_users_path, params: user_params(email: 'op@example.com', role: 'operator')
      expect(User.find_by!(email: 'op@example.com')).to be_worker
    end

    it '他社の組織IDを指定しても、自社のユーザーになる' do
      post admin_users_path, params: user_params(organization_id: other_organization.id)

      expect(User.find_by!(email: 'new@example.com').organization).to eq(organization)
    end

    it '名前が空、またはメールアドレスが重複していれば作成できない' do
      worker

      expect { post admin_users_path, params: user_params(name: '') }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)

      expect { post admin_users_path, params: user_params(email: worker.email) }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe '管理者: 作業者の編集' do
    before { sign_in admin }

    it '名前とメールアドレスを変更できる' do
      patch admin_user_path(worker), params: user_params(name: '改名', email: 'renamed@example.com')

      expect(response).to redirect_to(admin_users_path)
      expect(worker.reload).to have_attributes(name: '改名', email: 'renamed@example.com')
    end

    it '権限は変更できない（管理者への昇格もできない）' do
      patch admin_user_path(worker), params: user_params(email: worker.email, role: 'admin')

      expect(worker.reload).to be_worker
    end

    it '他社のユーザー・管理者・運営ユーザーは編集も更新もできない' do
      targets = [
        build_user(other_organization, 'other@example.com', :worker),
        build_user(organization, 'admin2@example.com', :admin),
        build_user(organization, 'operator@example.com', :operator)
      ]

      targets.each do |target|
        # 404 (例外)になったリクエストではセッションが保存されず、次のリクエストが未ログイン扱い(302)になるため、毎回ログインし直す
        sign_in admin
        get edit_admin_user_path(target)
        expect(response).to have_http_status(:not_found)

        sign_in admin
        patch admin_user_path(target), params: user_params(name: '乗っ取り', email: target.email)
        expect(response).to have_http_status(:not_found)
        expect(target.reload.name).not_to eq('乗っ取り')
      end
    end
  end

  describe '招待URLの再発行' do
    def token_from(invitation)
      Rack::Utils.parse_query(URI.parse(invitation['url']).query)['reset_password_token']
    end

    it '管理者は自社の作業者の招待URLを再発行でき、前のURLは使えなくなる' do
      sign_in admin
      old_token = worker.issue_invitation_token!

      post invitation_admin_user_path(worker)

      new_token = token_from(flash[:invitation])
      expect(response).to redirect_to(admin_users_path)
      expect(new_token).to be_present
      expect(new_token).not_to eq(old_token)
      expect(User.with_reset_password_token(old_token)).to be_nil
      expect(User.with_reset_password_token(new_token)).to eq(worker)
    end

    it '作業者は再発行できない' do
      sign_in worker

      post invitation_admin_user_path(worker)

      expect(response).to have_http_status(:forbidden)
    end

    it '他社のユーザーや管理者の招待URLは再発行できない' do
      sign_in admin

      post invitation_admin_user_path(build_user(other_organization, 'other@example.com', :worker))
      expect(response).to have_http_status(:not_found)

      sign_in admin # 404 の後はセッションが残らないので、ログインし直す
      post invitation_admin_user_path(build_user(organization, 'admin2@example.com', :admin))
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'メニューの出し分け' do
    it '管理者には「作業者の管理」と「作業範囲一覧」が表示される' do
      sign_in admin

      get root_path

      expect(response.body).to include(admin_users_path, work_areas_path)
      expect(response.body).not_to include(operator_organizations_path)
    end

    it '作業者と未ログインには「作業者の管理」が表示されない' do
      get root_path
      expect(response.body).not_to include(admin_users_path)

      sign_in worker
      get root_path
      expect(response.body).not_to include(admin_users_path)
      expect(response.body).to include(work_areas_path)
    end
  end
end
