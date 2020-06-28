<%= @open_module %>
  class <%=@class_name%>CommentsController < ApplicationController
    # GET /comments
    def index
      respond_to do |format|
        format.json do
          service = Fl::Framework::Service::Comment::ActiveRecord.new(<%=@full_class_name%>, current_user, params)
          @<%=@label%> = service.get_and_check_commentable(Fl::Framework::Comment::Commentable::ACCESS_COMMENT_INDEX, :<%=@label%>_id)
          if @<%=@label%> && service.success?
            r = service.index(@<%=@label%>, { includes: [ :author, :commentable ] }, query_params, pagination_params)
            if r
              render :json => {
                :comments => hash_objects(r[:result], service.params[:to_hash]),
                :_pg => r[:_pg]
              }
            else
              error_response(generate_error_info(service))
            end
          else
            error_response(generate_error_info(service))
          end
        end
      end
    end

    # POST /comments
    def create
      service = Fl::Framework::Service::Comment::ActiveRecord.new(<%=@full_class_name%>, current_user, nil, self)
      @comment = service.create_nested(owner_id_name: :<%=@label%>_id,
                                       owner_attribute_name: :commentable,
                                       permission: Fl::Framework::Comment::Commentable::ACCESS_COMMENT_CREATE)
      respond_to do |format|
        format.json do
          if service.success?
            render :json => { :comment => hash_one_object(@comment, params[:to_hash]) }
          else
            error_response(generate_error_info(service, @comment))
          end
        end
      end
    end

    private

    def query_params
      params.fetch(:_q, {}).permit(:order, :limit, :offset, { only_authors: [] }, { except_authors: [] })
    end

    def pagination_params()
      params.fetch(:_pg, {}).permit(:_s, :_p, :_c)
    end
  end
<%= @close_module %>
