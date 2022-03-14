require 'fl/core/list/db'

# This file contains hacks to set up the DB correctly for test runs.
# RSpec resets the test database by executing the schema.sql file (or at least that's the
# working assumption).
#
# Unfortunately, schema.sql does not record database objects like triggers and functions.
# As a consequence, those objects are missing, and any code that relies on them fails.
# (The typical example is triggers that manage tsvectors associated with a column.)
#
# In order to work around the reset behavior of RSpec, we need to define before(:suite)
# hooks that patch the DB back to its intended state.
#
# Note how the trigger managemen code has been extracted out of the migration files and placed in classes
# (in `lib`) so that it can be reused here.
# This eliminates inconsistencies between the migration code and the hack.
#
# This file is required by rails_helper, and therefore is picked up by all test suites.

module SpecDbHacks
end

if defined?(RSpec) && defined?(RSpec.configure)
  RSpec.configure do |c|
    c.before(:suite) do
      # we don't need to run the hacks if the schema format is :sql, since triggers and other nonstandard
      # features are defined in db/structure.sql
      
      if Rails.application.config.active_record.schema_format != :sql
      end
    end
  
     c.before(:suite) do
       Fl::Core::List::Db.register_list_item_state(1, 'selected', 'Selected (Normal)')
       Fl::Core::List::Db.register_list_item_state(2, 'deselected', 'Deselected')
     end
  end
end
