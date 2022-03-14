# This file contains global configuration settings for the tests.

module SpecGlobalConfig
end

if defined?(RSpec) && defined?(RSpec.configure)
  RSpec.configure do |c|
    c.include FactoryBot::Syntax::Methods
    c.include Fl::Core::Test::ObjectHelpers
  end
end

require 'support/spec_db_hacks'
