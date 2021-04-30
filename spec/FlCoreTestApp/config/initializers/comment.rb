Rails.application.config.after_initialize do
  # The name of the class to use to instantiate comment objects.
  Fl::Core::Comment.object_class_name = 'Fl::Test::Comment'
end
