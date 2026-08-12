Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Container probes use this for process liveness; external monitoring uses /ready below.
  get "up", to: "rails/health#show", as: :rails_health_check

  # Readiness includes a real database round-trip; keep /up as boot-only liveness.
  get "ready", to: "readiness#show", as: :readiness_check

  # PWA manifest active from birth (installable, real icon); offline and Web Push
  # service-worker behavior is Capability work, not schema-independent Core.
  get "manifest" => "rails/pwa#manifest", :as => :pwa_manifest

  get "privacy" => "pages#privacy"
  get "terms" => "pages#terms"

  # Branded error pages, reached through config.exceptions_app.
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable", via: :all
  match "/500", to: "errors#internal_error", via: :all

  root "home#index"

  # Defines the root path route ("/")
  # root "posts#index"

  # The app people actually use. The Compiler's CRUD routes below are the
  # authoring substrate; these are the two experiences the product is about.
  resources :cases, only: %i[index show] do
    collection { post :join }
    member { post :restart }
    resources :threads, only: :create, module: :cases
  end

  resources :threads, only: :show do
    resources :messages, only: :create, module: :threads
  end

  # Authoring: building the case and its cast.
  namespace :author do
    resources :cases, only: %i[index new create edit update] do
      member { post :publish }
      resource :cohort, only: :show, module: :cases
      resources :contacts, only: %i[index new create edit update destroy]
    end
    resources :contacts, only: [] do
      resources :referrals, only: %i[create destroy], module: :contacts
      resources :share_rules, only: %i[create destroy], module: :contacts
    end
  end

  # The Compiler emits App-Schema-derived routes after Core's reserved routes.
  draw :foundation_domain
end
