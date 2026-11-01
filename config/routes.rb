Rails.application.routes.draw do
  devise_for :users, skip: [:registrations]
  root "calculator#index"
  post "calculate", to: "calculator#calculate"
  post "/area/triangulate", to: "calculator#triangulate"
  get "/area", to: "calculator#area"
  get "/area/calculate", to: "calculator#calculate_area"
  get "/terms", to: "legal_pages#terms"
  get "/privacy_policy", to: "legal_pages#privacy_policy"
  resources :work_areas, only: %i[index new show create edit update] do
    member { patch :measurements }
  end

  # 会社の管理者(admin)だけが使える、自社の作業者の管理画面
  namespace :admin do
    root to: "users#index"
    resources :users, only: %i[index new create edit update] do
      member { post :invitation }
    end
    resources :estimates, only: %i[index show new create edit update destroy] do
      resources :estimate_lines, path: 'lines', only: %i[create update destroy]
    end
    resource :estimate_setting, only: %i[edit update]
    resources :cost_categories, only: %i[index edit create update destroy]
    resources :cost_items, only: %i[index new edit create update destroy]
  end

  # 運営(operator)だけが使える、組織とアカウントの管理画面
  namespace :operator do
    root to: "organizations#index"
    resources :organizations, only: %i[index new create show edit update] do
      resources :users, only: %i[new create] do
        member { post :invitation }
      end
    end
  end

  # ログイン中のユーザーが自分のパスワードを変更する
  resource :account_password, only: %i[edit update], path: "account/password"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
