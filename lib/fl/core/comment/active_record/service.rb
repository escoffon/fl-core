require 'fl/core/service'
require 'fl/core/comment'

module Fl::Core::Comment::ActiveRecord
  # Service object for comments that use an Active Record database.
  # This service manages comments in a flat space, and relies on submission parameters to determin the target
  # commentables (if any).
  # Using this, rather than a service nested inside a commentable instance, makes for a cleaner API, at the cost
  # of additional checks on each request. With nested services, there would have to be a controller for each
  # commentable class, which makes for a busier API with a fair amount of redundant operations.

  class Service < Fl::Core::Service::Base
    self.model_class = Fl::Core::Comment::ActiveRecord::Comment

    # Initializer.
    #
    # @param actor [Object] The actor (typically an object that mixed in {Fl::Core::Actor})
    #  on whose behalf the service operates. It may be `nil`.
    # @param params [Hash, ActionController::Parameters] The processing parameters. If the value is `nil`,
    #  the parameters are obtained from the `params` property of *controller*. If *controller* is also
    #  `nil`, the value is set to an empty hash. Hash values are converted to `ActionController::Parameters`.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options. See {Fl::Core::Service::Nested#initialize}.

    def initialize(actor, params = nil, controller = nil, cfg = {})
      @query_params = nil
      
      super(actor, params, controller, cfg)
    end

    # Get query parameters.
    #
    # @param p [Hash,ActionController::Params,String] The parameter value.
    #
    # @return [ActionController::Parameters] Returns the query parameters.

    def query_params(p = nil)
      if @query_params.nil?
        # We do not allow :except_commentables, because it opens a security hole if we are not careful, and it is
        # a low use option anyway.
        # Also, we convert :only_commentables to objects, which the access control needs to check for permissions
      
        @query_params = normalize_query_params(p).permit({ only_commentables: [ ] },
                                                         { only_authors: [ ] }, { except_authors: [ ] },
                                                         :created_after, :updated_after, :created_before, :updated_before,
                                                         :order, :limit, :offset)
        only_c = convert_list_of_polymorphic_references(@query_params[:only_commentables])
        @query_params[:only_commentables] = _instantiate_object_list(only_c)
      end
      
      @query_params
    end

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def create_params(p = nil)
      # :author is implicit in the actor
      cp = strong_params(p).require(:fl_core_comment).permit(:commentable, :title, :contents, :contents_delta)
      cp[:author] = actor
      cp
    end

    # Get update parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def update_params(p = nil)
      # :commentable and :author may not be modified
      cp = strong_params(p).require(:fl_core_comment).permit(:title, :contents, :contents_delta)
      cp.delete(:commentable)
      cp.delete(:author)
      cp
    end

    protected

    # Perform the permission check for an action.
    # Overrides the superclass for the following actions:
    #
    # - **index** iterates over all elements in **:only_ommentables** and for each confirms that {#actor}
    #   has {Fl::Core::Comment::Permission::IndexContents} permission. If all commentables grant permission,
    #   returns `true`; otherwise, return `false`.
    # - **create** returns `false` if {#actor} is `nil`.
    #   Otherwise, it checks if the **:commentable** from {#create_params} grants
    #   {Fl::Core::Comment::Permission::CreateComments} to {#actor}.
    # - **update** returns `false` if {#actor} is `nil`, or if {#actor} is not the comment's author.
    #
    # @param action [String] The action for which to check for permission; the value has been normalized to a
    #  string by {#has_action_permission?}.
    # @param obj [Object,Class] The object to use to check the permission.
    #  For collection-level actions like `index` and `create`, this is typically {#model_class};
    #  for member-level actions like `update`, it is typically an instance of {#model_class}.
    # @param opts [Hash] A hash of options to pass to the access check methods.
    #
    # @return [Boolean] Returns `false` if the permission is not granted.

    def _has_action_permission?(action, obj, opts = nil)
      case action
      when 'index'
        if query_params[:only_commentables].is_a?(Array)
          not_granted = query_params[:only_commentables].reduce([ ]) do |acc, c|
            if c.respond_to?(:has_permission?) && \
               !c.has_permission?(Fl::Core::Comment::Permission::IndexComments::NAME, actor)
              acc << c
            end
            acc
          end

          return (not_granted.count > 0) ? false : true
        else
          return true
        end
      when 'create'
        return false if self.actor.nil?
        commentable = Fl::Core::Comment::Helper.commentable_from_parameter(create_params[:commentable])
        return false if commentable.nil?
        return true unless commentable.respond_to?(:has_permission?)
        return commentable.has_permission?(Fl::Core::Comment::Permission::CreateComments::NAME, self.actor, opts)
      when 'update'
        return false if self.actor.nil? || (self.actor.fingerprint != obj.author.fingerprint)
        return true        
      else
        return super(action, obj, opts)
      end
    end

    # Run a query to implement the **:index** action.
    # Modifes the query options *query_opts* to remove any for which *actor* has no permission, and then
    # runs the query.
    #
    # @param query_opts [Hash] A hash of query options to build the query.
    #
    # @return [ActiveRecord::Relation, nil] Returns an instance of ActiveRecord::Relation, or `nil`
    #  on error.

    def index_query(query_opts = {})
      # :only_commentables drops objects that do not grant {#actor} `index_comments`, and for good measure
      # we ignore :except_commentables
      #
      # The :only_commentable value is already in objects, and strictly speaking we don't need the filter,
      # since the access check has failed if any commentables are not indexable (by actor), but we leave the
      # filter in just in case.
      # Similarly there should not be a need to call _instantiate_object_list here

      query_opts.delete(:except_commentables)
      only_objects = _filter_object_list(_instantiate_object_list(query_opts[:only_commentables]))

      # if only_objects is empty, then we return no results: we must have at least one commentable

      return self.model_class.none if !only_objects.is_a?(Array) || (only_objects.count < 1)

      query_opts[:only_commentables] = only_objects.map { |o| o.fingerprint }

      # the other query options can be passed to the query as they are

      return self.model_class.build_query(query_opts)
    end

    private

    def _instantiate_object_list(ol)
      return nil if ol.nil?
      ol = [ ol ] unless ol.is_a?(Array)

      oh = ol.reduce({ }) do |acc, fp|
        if fp.is_a?(String)
          klass, id = self.model_class.split_fingerprint(fp)
        elsif fp.is_a?(ActiveRecord::Base)
          klass = fp.class.name
          id = fp
        end

        if acc.has_key?(klass)
          acc[klass] << id
        else
          acc[klass] = [ id ]
        end
        acc
      end

      oh.reduce([ ]) do |acc, kvp|
        klass, kl = kvp
        begin
          objs, ids = kl.partition { |o| o.is_a?(ActiveRecord::Base) }
          acc.concat(objs)
          acc.concat(klass.constantize.where('(id IN (?))', ids)) if ids.count > 0
        rescue => x
        end

        acc
      end
    end

    def _filter_object_list(ol)
      return nil if ol.nil?
      ol = [ ol ] unless ol.is_a?(Array)

      fl = ol.reduce([ ]) do |acc, o|
        if o.respond_to?(:has_permission?)
          if o.has_permission?(Fl::Core::Comment::Permission::IndexComments::NAME, actor)
            acc << o
          end
        else
          acc << o
        end

        acc
      end

      return (fl.count > 0) ? fl : nil
    end
  end
end
