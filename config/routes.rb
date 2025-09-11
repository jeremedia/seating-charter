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
    collection do
      post :upload_roster
    end
    
    resources :students, except: [:show]
    resources :import_sessions, except: [:show]
    
    # Import workflow
    resources :imports, only: [:new, :create, :show]
    resources :import_sessions do
      resources :import_reviews, except: [:show, :destroy] do
        collection do
          patch :bulk_update
          patch :confirm
        end
      end
    end
    
    resources :seating_events do
      member do
        post :generate
        get :export_all_days
      end
      
      # Export routes at seating_event level
      resources :exports, only: [:index] do
        collection do
          post :bulk_export
          get :formats
        end
      end
      
      resources :seating_arrangements, except: [:show] do
        # Export routes for individual arrangements
        resources :exports, except: [:show, :edit, :update, :destroy] do
          member do
            get :preview
            get :status
            get :download
            post :email_export
          end
        end
        
        # Explanation routes
        resources :arrangement_explanations, path: :explanations, only: [:show] do
          member do
            get 'table/:table_number', to: 'arrangement_explanations#table', as: :table
            get 'student/:student_id', to: 'arrangement_explanations#student', as: :student
            get :diversity
            get :constraints
            get :optimization
            post :generate
            get :export
            get :interactive_chart
            get :why_not
          end
        end
      end
      resources :seating_instructions, except: [:show]
      resources :seating_rules do
        member do
          patch :toggle
        end
        collection do
          post :preview
          post :batch_parse
          get :validate
        end
      end
      
      # Seating optimization routes
      resources :seating_optimizations, except: [:index, :edit, :update, :destroy] do
        member do
          get :export
        end
        collection do
          get :compare
          post :optimize_async
          get :optimization_status
        end
      end

      # Seating editor routes
      resources :seating_arrangements, only: [] do
        member do
          get :edit_seating, to: 'seating_editors#edit'
          post :move_student, to: 'seating_editors#move_student'
          post :swap_students, to: 'seating_editors#swap_students'
          post :create_table, to: 'seating_editors#create_table'
          delete 'delete_table/:table_number', to: 'seating_editors#delete_table', as: :delete_table
          post :balance_tables, to: 'seating_editors#balance_tables'
          post 'shuffle_table/:table_number', to: 'seating_editors#shuffle_table', as: :shuffle_table
          post :undo, to: 'seating_editors#undo'
          post :auto_save, to: 'seating_editors#auto_save'
          get :status, to: 'seating_editors#status'
          post :lock, to: 'seating_editors#lock'
          post :unlock, to: 'seating_editors#unlock'
          get :search_students, to: 'seating_editors#search_students'
          post :apply_template, to: 'seating_editors#apply_template'
          get :export, to: 'seating_editors#export'
        end
      end
      
      # Multi-day optimization routes
      resources :multi_day_optimizations, except: [:index, :edit, :update, :destroy] do
        member do
          get :export
          get :calendar
          get :interactions
          get :analytics
          get :day_arrangement
          patch :update_day_arrangement
        end
        collection do
          post :optimize_async
          get :optimization_status
          get :preview_rotation
          post :bulk_optimize
        end
      end
    end
  end
  
  # Admin routes (for AI configuration and custom attributes)
  namespace :admin do
    resources :ai_configurations do
      member do
        patch :activate
        patch :test
      end
    end
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
