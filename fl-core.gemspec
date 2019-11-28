lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fl/core/version"

Gem::Specification.new do |spec|
  spec.name          = "fl-core"
  spec.version       = Fl::Core::VERSION
  spec.authors       = ["Emil Scoffone"]
  spec.email         = ["emil@scoffone.com"]

  spec.summary       = "Floopstreet core functionality."
  spec.description   = "Contains the Floopstreet core functionality."
  #- Will need a real URL at some point
  #- spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  #- Will need a valid URL at some point
  #- spec.metadata["homepage_uri"] = spec.homepage
  #- spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  #- spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  # an alternative approach is to use a tailored list:
  # spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # This gem requires Rails 6
  spec.add_runtime_dependency "rails", "~> 6.0.1"

  spec.add_runtime_dependency "nokogiri", "~> 1.10"
  spec.add_runtime_dependency "loofah", "~> 2.3"
  spec.add_runtime_dependency 'fl-google'
  
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  # The following are loaded in development mode so that we can run the test app
  # and use it to run generators
  spec.add_development_dependency 'bootsnap', '>= 1.4.2'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
  spec.add_development_dependency 'listen', '>= 3.0.5', '< 3.2'
end
