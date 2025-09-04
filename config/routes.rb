Rails.application.routes.draw do
  get "home/index"
  get "dashboard/index"
  devise_for :users
  
  # Root route
  root "dashboard#index"
  
  # Dashboard routes
  get "dashboard", to: "dashboard#index"
  
  # Cohorts management
  resources :cohorts do
    resources :students, except: [:show]
    resources :import_sessions, except: [:show]
    resources :seating_events do
      resources :seating_arrangements, except: [:show]
      resources :seating_instructions, except: [:show]
    end
  end
  
  # Admin routes (for AI configuration and custom attributes)
  namespace :admin do
    resources :ai_configurations
    resources :custom_attributes
    resources :cost_trackings, only: [:index, :show]
    resources :users, only: [:index, :show, :edit, :update, :destroy]
  end
  
  # API routes for AJAX requests
  namespace :api do
    namespace :v1 do
      resources :students, only: [:index, :show]
      resources :seating_arrangements, only: [:create, :update]
      post 'ai/infer_attributes', to: 'ai#infer_attributes'
      post 'seating/optimize', to: 'seating#optimize'
    end
  end
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
