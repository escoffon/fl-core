$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "fl/core/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "fl-core"
  spec.platform    = Gem::Platform::RUBY
  spec.version     = Fl::Core::VERSION
  spec.date        = Fl::Core::DATE
  spec.authors     = ["Emil Scoffone"]
  spec.email       = ["emil@scoffone.com"]
  #- Will need a real URL at some point
  #-spec.homepage    = "TODO"
  spec.summary     = "Floopstreet core functionality."
  spec.description = "Contains the Floopstreet core functionality."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_runtime_dependency "nokogiri", "~> 1.10"
  spec.add_runtime_dependency "loofah", "~> 2.3"
  #- spec.add_runtime_dependency 'fl-google'
  spec.add_runtime_dependency "mimemagic", "~> 0.3"
  
  spec.add_development_dependency "rails", "~> 6.0.2", ">= 6.0.2.1"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"

  # The following are loaded in development mode so that we can run the test app
  # and use it to run generators
  spec.add_development_dependency 'bootsnap', '>= 1.4.2'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
  spec.add_development_dependency 'listen', '>= 3.0.5', '< 3.2'
end
