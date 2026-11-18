Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :api do
    namespace :auth do
      post "institutions", to: "institutions#create"
      post "register", to: "registrations#create"
      post "login", to: "login#create"
      post "logout", to: "logouts#create"
      post "password/reset", to: "passwords#create"
    end

    namespace :v1 do
      resources :languages, only: %i[index show]
      resources :book_formats, only: %i[index show]
      resources :authors, only: %i[index show create update] do
        member { post :archive }
      end
      resources :publishers, only: %i[index show create update] do
        member { post :archive }
      end
      resources :categories, only: %i[index show create update] do
        member { post :archive }
      end
      resources :subjects, only: %i[index show create update] do
        member { post :archive }
      end
      resources :genres, only: %i[index show create update] do
        member { post :archive }
      end
      resources :books, only: %i[index show create update destroy] do
        resources :editions, only: %i[index create]
        member do
          post :publish
          post :archive
          post :submit
          post :reject
          post :withdraw
          get :audit_logs
          post :authors, action: :add_author
          delete "authors/:author_link_id", action: :remove_author
          post :subjects, action: :add_subject
          delete "subjects/:subject_id", action: :remove_subject
          post :categories, action: :add_category
          delete "categories/:category_id", action: :remove_category
          post :genres, action: :add_genre
          delete "genres/:genre_id", action: :remove_genre
          post :media, action: :add_media
        end
      end
      resources :editions, only: %i[show update destroy] do
        member do
          post :identifiers, action: :add_identifier
          post :contributors, action: :add_contributor
        end
      end
    end
  end
end
