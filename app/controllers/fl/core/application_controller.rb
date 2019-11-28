module Fl
  module Core
    # Base class for {Fl::Core} controllers.
    
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception
    end
  end
end
