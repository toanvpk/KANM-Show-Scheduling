Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root to: redirect("login/index")
  get "login/index", to: "login#index", as: "login"
  post "/logout", to: "sessions#logout", as: "logout"
  get "/auth/google_oauth2/callback", to: "sessions#omniauth"
  get "sessions/logout"
  get "sessions/omniauth"

  resources :admins
  get "welcome/index", to: "welcome#index", as: "welcome"
  get "welcome/download", to: "download#download", as: "download"
  resources :uploads, only: [ :new, :create ]
end
