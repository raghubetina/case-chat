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
  # `show` is the directory; the rest are the other panes of the same shell, so
  # each one is a real URL you can link to, reload, and go back to.
  resources :cases, only: %i[index show] do
    collection do
      # Same path, two verbs: the form is a pane of the shell, submitting it
      # enrolls you.
      get "join", to: "cases#new_join", as: :new_join
      post "join", to: "cases#join", as: :join
    end
    member do
      post :restart
      get :background
      get :assignment
      get :files
      get :collected
      get :search
    end
    resources :threads, only: :create, module: :cases
  end

  # Downloads go through the app so DocumentPolicy decides, rather than handing
  # out a signed blob URL that outlives the permission that produced it.
  resources :documents, only: [] do
    member { get :download }
  end

  resources :threads, only: :show do
    resources :messages, only: :create, module: :threads
  end

  # Authoring: building the case and its cast.
  namespace :author do
    resources :cases, only: %i[index new create edit update] do
      member do
        post :publish
        get :search
      end
      resource :cohort, only: :show, module: :cases
      # One student's runs, read side by side. Nested under the case because a
      # student only exists here as somebody enrolled in it.
      resources :students, only: :show, module: :cases
      resource :usage, only: :show, module: :cases
      resources :documents, only: %i[index new create destroy], module: :cases
      resource :import, only: %i[new create], module: :cases
      resources :contacts, only: %i[new create edit update destroy] do
        # Rehearsing a stakeholder. Singular: one live transcript per author.
        resource :test_drive, only: %i[create destroy], module: :contacts
        # The runs of this person, read side by side.
        resources :test_drives, only: :index, module: :contacts
      end
    end
    resources :contacts, only: [] do
      resources :referrals, only: %i[create destroy], module: :contacts
      resources :share_rules, only: %i[create destroy], module: :contacts
    end
  end

  # The Compiler emits App-Schema-derived routes after Core's reserved routes.
  draw :foundation_domain
end
