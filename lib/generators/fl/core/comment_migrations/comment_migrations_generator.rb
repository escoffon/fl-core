module Fl::Core
  class CommentMigrationsGenerator < Rails::Generators::Base
    include Fl::Core::GeneratorHelper
    
    desc <<-DESC
  This generator copies the comment migration file to the application's db/migrate directory.

  For example, given this command:
    rails generate fl:core:comment_migrations

  The generator will create:
    db/migrate/TS_create_fl_core_comments.fl_core.rb
  where TS is a timestamp.
DESC

    PWD = File.expand_path('.')
    DB_MIGRATE = File.expand_path('../../../../../../db/migrate', __FILE__)
    MIGRATION_FILE_NAMES = [ 'create_fl_core_comments' ]
    
    source_root File.expand_path('../templates', __FILE__)

    def create_migration_files
      MIGRATION_FILE_NAMES.each { |fn| create_migration_file(DB_MIGRATE, fn) }
    end
  end
end
