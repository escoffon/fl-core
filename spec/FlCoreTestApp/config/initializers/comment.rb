Rails.application.config.after_initialize do
  require 'fl/core/comment_init'

  # The name of the class to use to instantiate comment objects.
  Fl::Core::Comment.object_class_name = 'Fl::Test::Comment'

  require 'fl/core/comment'
end
