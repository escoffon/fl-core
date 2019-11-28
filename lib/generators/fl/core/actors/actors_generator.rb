module Fl::Core
  class ActorsGenerator < Rails::Generators::Base
    include Fl::Core::GeneratorHelper
    
    desc <<-DESC
  This generator installs support for actor functionality.
  It copies the actors migration file to the application's db/migrations directory.

  For example, given this command:
    rails generate fl:core:actors

  The generator will create:
    db/migrate TS_create_actors_groups.fl_core.rb
  where TS is a timestamp.
DESC

    PWD = File.expand_path('.')
    DB_MIGRATE = File.expand_path('../../../../../../db/migrate', __FILE__)
    MIGRATION_FILE_NAMES = [ 'create_actor_groups' ]
    
    source_root File.expand_path('../templates', __FILE__)

    def create_migration_files
      MIGRATION_FILE_NAMES.each { |fn| create_migration_file(DB_MIGRATE, fn) }
    end
  end
end
