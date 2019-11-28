ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
#- commented out. The test app is also used by the gem, and we don't really want to add this dependency to it
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
