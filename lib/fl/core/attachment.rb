module Fl::Core
  # Attachment support.
  # This module contains a number of mixin modules used to manage file attachments.
  # An earlier implementation used the Paperclip gem ({https://github.com/thoughtbot/paperclip});
  # However, Paperclip has been deprecated in Rails 5+ in favor of Active Storage, and the module
  # now provides just Active Storage extensions.
  #
  # See {Fl::Core::Attachment::ActiveStorage} for details.
  
  module Attachment
  end
end

require 'fl/core/attachment/configuration'

if defined?(ActiveStorage)
  require 'fl/core/attachment/active_storage'
end
