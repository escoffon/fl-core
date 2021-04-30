# This is the service object class that extends and overrides the core service object functionality.
# It assumes that we are using ActiveRecord.

class Fl::Test::CommentService < Fl::Core::Comment::ActiveRecord::Service
  # This statement overrides the class used to manage comment instances

  self.model_class = Fl::Test::Comment

  protected

  # Perform the permission check for an action.
  # The starting implementation calls to the superclass; this is where you would override the access
  # behavior of the service object.
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
    return _has_action_permission?(action, obj, opts)
  end
end
