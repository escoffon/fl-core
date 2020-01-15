module Fl::Core::Attachment
  # Namespace for ActiveStorage support.
  # This module is partitioned among the following submodules:
  #
  # - {Base} defines a number of core methods, mostly for use by the other modules.
  # - {Macros} extends the `has_one_attached` and `has_many_attached` ActiveStorage macros to support
  #   registration of standard "styles" (variants, in ActiveStorage terminology) for the attachment.
  # - {Helper} defines a number of helper methods to manage URLs to blobs and variants, and to generate
  #   hash representations of attachments, for use in implementations of
  #   {Fl::Core::ModelHash::InstanceMethods#to_hash_local}.
  # - {Validation} defines validators for ActiveStorage attachments.
  #
  # All four are included if this module is included.
  
  module ActiveStorage
  end
end

require 'fl/core/attachment/active_storage/base'
require 'fl/core/attachment/active_storage/helper'
require 'fl/core/attachment/active_storage/macros'
require 'fl/core/attachment/active_storage/validation'

module Fl::Core::Attachment
  module ActiveStorage
    # Perform actions when the module is included.
    # - Includes {Fl::Core::Attachment::ActiveStorage::Base}, {Fl::Core::Attachment::ActiveStorage::Helper},
    #   {Fl::Core::Attachment::ActiveStorage::Macros}, and {Fl::Core::Attachment::ActiveStorage::Validation}

    def self.included(base)
      base.include Base
      base.include Helper
      base.include Macros
      base.include Validation
    end
  end
end
