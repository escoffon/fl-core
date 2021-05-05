module Fl::Core
  # The namespace module for comment code.

  module Comment
    # The name of the class to use to instantiate comment objects.
    # The default is {Fl::Core::Comment::ActiveRecord::Comment}; when the comment generator is executed,
    # an initializer is generated to overwrites this value with the class defined by the generator via
    # the `--object_class` option.

    mattr_accessor :object_class_name
    self.object_class_name = 'Fl::Core::Comment::ActiveRecord::Comment'
  end
end
