require "fl/core/version"

# Namespace for Floopstreet code.

module Fl
  # Namespace for Floopstreet core code.
  
  module Core
    # The {Fl::Core} base error class.
    
    class Error < StandardError ; end
  end
end

require 'fl/core/model_hash'
require 'fl/core/attribute_filters.rb'
require 'fl/core/html_helper.rb'
require 'fl/core/i18n.rb'
require 'fl/core/icalendar.rb'
require 'fl/core/model_hash.rb'
require 'fl/core/parameters_helper.rb'
require 'fl/core/time_zone.rb'
require 'fl/core/title_management.rb'
