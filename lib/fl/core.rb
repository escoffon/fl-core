require "fl/core/engine"
require "fl/core/version"

# Namespace for Floopstreet code.

module Fl
  # Namespace for Floopstreet core code.
  
  module Core
    # The {Fl::Core} base error class.
    
    class Error < StandardError ; end
  end
end

require 'fl/core/attribute_filters'
require 'fl/core/captcha'
require 'fl/core/generator_helper'
require 'fl/core/html_helper'
require 'fl/core/i18n'
require 'fl/core/icalendar'
require 'fl/core/model_hash'
require 'fl/core/parameters_helper'
require 'fl/core/query'
require 'fl/core/time_zone'
require 'fl/core/title_management'

require 'fl/core/db'
require 'fl/core/access'
require 'fl/core/actor'
require 'fl/core/attachment'
require 'fl/core/test'
