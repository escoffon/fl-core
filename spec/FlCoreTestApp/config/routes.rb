Rails.application.routes.draw do
  namespace :fl do
    namespace :test do
      resources :comments, only: [ :index, :create, :update ]
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
