module Fl::Core
  class CommentsController < ApplicationController
    include Fl::Core::Concerns::Service::ApiResponse
    include Fl::Core::Concerns::Controller::ServiceStatus
    include Fl::Core::Concerns::Service::Params

    private

    def service_class
      Fl::Core::Comment::ActiveRecord::Service
    end

    public
    
    def current_user
      # for testing purposes, get the current user from a header

      cu = nil
      unless request.headers[:HTTP_CURRENTUSER].nil?
        begin
          cu = ActiveRecord::Base.find_by_fingerprint(request.headers[:HTTP_CURRENTUSER])
        rescue => x
        end
      end
      cu
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
