Rails.application.routes.draw do
  namespace :fl do
    namespace :core do
      resources :comments, only: [ :index, :create ]
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
