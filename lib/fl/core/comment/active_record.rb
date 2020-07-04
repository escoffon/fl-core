module Fl::Core::Comment
  # The namespace module for ActiveRecord-specific comment code.

  module ActiveRecord
  end
end

require 'fl/core/comment/active_record/commentable'
require 'fl/core/comment/active_record/comment'
require 'fl/core/comment/active_record/service'
