Rails.application.config.after_initialize do
  require 'fl/core/comment_init'

  # The name of the class to use to instantiate comment objects.
  Fl::Core::Comment.object_class_name = '<%=@comment_object_class%>'

  require 'fl/core/comment'
end
