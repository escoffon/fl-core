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

require 'fl/core/comment/permission'
require 'fl/core/comment/checker'
require 'fl/core/comment/common'
require 'fl/core/comment/helper'
if defined?(ActiveRecord)
  require 'fl/core/comment/active_record'
end
require 'fl/core/comment/commentable'
