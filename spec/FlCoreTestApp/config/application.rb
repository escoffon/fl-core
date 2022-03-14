require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FlCoreTestApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Additional locale dictionaries with the fl-core translations
    config.i18n.load_path += Dir[Rails.root.dirname.dirname.join('config', 'locales', '**', '*.{rb,yml}')]

    # Use the SQL schema format, since we use features not supported by migrations (like triggers)
    # config.active_record.schema_format = :sql
  end
end
