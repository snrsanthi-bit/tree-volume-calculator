Rails.application.routes.draw do
  devise_for :users, skip: [:registrations]
  root "calculator#index"
  post "calculate", to: "calculator#calculate"
  get "/area", to: "calculator#area"
  get "/area/calculate", to: "calculator#calculate_area"
  get "/terms", to: "legal_pages#terms"
  get "/privacy_policy", to: "legal_pages#privacy_policy"
  resources :work_areas, only: %i[index new show create edit update]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
