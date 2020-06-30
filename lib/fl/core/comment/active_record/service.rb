# Service object for ActiveRecord comments.
# This service object implements a non-nested API to manage comment instances.
# It detects if commentables implement access control, and if so it performs some standard permission
# checks.
#
# This class should be extended by applications to implement processing in an application controller.

class Fl::Core::Comment::ActiveRecord::Service < Fl::Core::Service::Base
  self.model_class = Fl::Core::Comment::ActiveRecord::Comment
    
  protected

  # Perform the permission check for an action.
  # Overrides the superclass as follows:
  #
  # - Returns `true` for the `index` action. Note that the topic permissions for {#actor} will place
  #   restrictions of the result set.
  # - For the `create` action, check if {#actor} has {Kp::Core::Topic::Permission::Post} access on the
  #   topic in {#create_params}. If so, returns `true`; otherwise, returns `false`.
  # - For the `show` action, return `true` if {#actor} is *obj*'s author. Also return `true` if {#actor} has
  #   {Fl::Core::Access::Permission::Read} permission on *obj*'s topic. Otherwise, return `false`.
  # - For the `update` action, return `false` if {#actor} is not *obj*'s author. Then, check if
  #   if the {#update_params} include a new topic (in other words, if the operation moves the item to a different
  #   topic): if so, {#actor} must have {Kp::Core::Topic::Permission::Post} access on the new topic.
  #   This prevents the author from moving the content item to a topic to which it does not have access.
  # - For the `destroy` action, return `true` if {#actor} is *obj*'s author. Otherwise, return `false`.
  # - For the `attach_local_image` action, return `true` if {#actor} is *obj*'s author. Otherwise, return `false`.
  # - For the `detach_local_image` action, return `true` if {#actor} is *obj*'s author. Otherwise, return `false`.
  # - For the `search` action, return `true` to allow it unconditionally. The topic permissions for {#author}
  #   will place restrictions on the result set just as for `index`.
  # - Returns `false` for everything else.
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
    when 'index', 'search'
      return true
    when 'create'
      tid = create_params[:topic]
      return Kp::Core::Topic.access_checker.access_check(Kp::Core::Topic::Permission::Post, actor, tid)
    when 'show'
      return true if actor.fingerprint == obj.author_fingerprint
      tid = Kp::Core::Topic.fingerprint(obj.topic_id)
      return Kp::Core::Topic.access_checker.access_check(Fl::Core::Access::Permission::Read, actor, tid)
    when 'update'
      return false if actor.fingerprint != obj.author_fingerprint
      tid = update_params[:topic]
      return (tid.nil? || (tid.to_i == obj.topic_id)) ? true : Kp::Core::Topic.access_checker.access_check(Kp::Core::Topic::Permission::Post, actor, tid)
    when 'destroy', 'attach_local_image', 'detach_local_image'
      return (actor.fingerprint == obj.author_fingerprint)
    else
      return false
    end
  end

  # Build a query to list objects.
  # This implementation first adjusts the query options to account for tracking directives for {#actor}, and
  # then calls {Kp::Content::Item.build_query}.
  #
  # @param query_opts [Hash] A hash of query options to build the query.
  #
  # @return [ActiveRecord::Relation, nil] Returns an instance of ActiveRecord::Relation, or `nil`
  #  on error.

  def index_query(query_opts = {})
    adjust_topic_and_author_options(actor, query_opts)
    Kp::Content::Item.build_query(query_opts)
  end

  # Get query parameters.
  #
  # @param p [Hash,ActionController::Params,String] The parameter value.
  #
  # @return [ActionController::Parameters] Returns the query parameters.

  def query_params(p = nil)
    return normalize_query_params(p).permit({ only_commentables: [ ] }, { except_commentables: [ ] },
                                            { only_authors: [ ] }, { except_authors: [ ] },
                                            :created_after, :updated_after, :created_before, :updated_before,
                                            :order, :limit, :offset)
  end

  # Get create parameters.
  #
  # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
  #  subset. If `nil`, use {#params}.
  #
  # @return [ActionController::Parameters] Returns the create parameters.

  def create_params(p = nil)
    # :author is implicit in the actor
    cp = strong_params(p).require(:comment).permit(:title, :contents, :contents_delta)
    cp[:author] = actor
    cp
  end

  # Get update parameters.
  #
  # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
  #  subset. If `nil`, use {#params}.
  #
  # @return [ActionController::Parameters] Returns the create parameters.

  def update_params(p = nil)
    # :author may not be modified
    cp = strong_params(p).require(:comment).permit(:title, :contents, :contents_delta)
    cp.delete(:author)
    cp
  end

  private

  def _adjust_topics(only, tp)
    mask = Fl::Core::Access::Helper.permission_mask(Fl::Core::Access::Permission::IndexContents::NAME)
    only = [ only ] if !only.nil? && !only.is_a?(Array)
    
    if only.nil? || (only.count < 1)
      # if the `only` list is empty, the caller has asked for all accessible topics

      tp.reduce([ ]) do |acc, kvp|
        k, v = kvp
        
        if v.has_key?('permission_mask') && ((v['permission_mask'] & mask) == mask)
          acc << k
        end

        acc
      end
    else
      # if it is not empty, we need to filter through only the accessible ones
      
      convert_list_of_polymorphic_references(only).reduce([ ]) do |acc, tfp|
        if tp.has_key?(tfp) && tp[tfp].has_key?('permission_mask') && ((tp[tfp]['permission_mask'] & mask) == mask)
          acc << tfp
        end

        acc
      end
    end
  end
end
