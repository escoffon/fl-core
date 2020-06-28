module Fl::Core
  # The namespace module for comment code.

  module Comment
  end
end

require 'fl/core/comment/permission'
require 'fl/core/comment/checker'
require 'fl/core/comment/common'
require 'fl/core/comment/helper'
require 'fl/core/comment/commentable'
if defined?(ActiveRecord)
  require 'fl/core/comment/active_record'
end
