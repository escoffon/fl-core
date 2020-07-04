module Fl::Core
  class CommentsController < ApplicationController
    include Fl::Core::Concerns::Service::ApiResponse
    include Fl::Core::Concerns::Controller::ServiceStatus
    include Fl::Core::Concerns::Service::Params

    private

    # This is the service object class used by the controller.
    # If you need to install a different class, change it here.
    
    def service_class
      Fl::Core::Service::Comment::ActiveRecord
    end

    public

    # current_user is the standard name of the method that returns the authenticated user
    # in Devise and related authentication frameworks. It is defined automatically.
    # This definition is used to provide a backstop for use by the service initializer;
    # note that it returns `nil`, to indicate that the user is not authenticated.
    #
    # For example, to add authentication with devise_token_auth, uncomment the following
    # include statement and comment out the definition of current_user.
    #
    # Note that a better way to turn on authentication for the whole application is by
    # adding the include statement in ApplicationController; in that case, all you need to
    # do is comment out current_user.

    # include DeviseTokenAuth::Concerns::SetUserByToken

    def current_user
      nil
    end
    
    # GET /fl/core/comments
    def index
      @service = service_class.new(current_user, params, self)
      r = @service.index({ includes: [ :author, :commentable ] })
      respond_to do |format|
        format.json do
          if r
            render_success_response('', :ok, {
                                      comments: hash_objects(r[:result], @service.to_hash_params),
                                      :_pg => r[:_pg]
                                    })
          else
            render_error_response_from_service('query_failure', @service, @service.status[:status])
          end
        end
      end
    end

    # POST /fl/core/comments
    def create
      @service = service_class.new(current_user, params, self)
      @comment = @service.create
      if @comment
        respond_to do |format|
          format.json do
            if @service.success?
              render_success_response('', :ok, {
                                        comment: hash_one_object(@comment, @service.to_hash_params)
                                      })
            else
              render_error_response_from_service('create_failure', @service, @service.status[:status])
            end
          end
        end
      else
        render_error_response_from_service('create_failure', @service, @service.status[:status])
      end
    end
  end
end