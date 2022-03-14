# Database/migration functionality to manage list-specific entities.
# This module defines the {.register_list_item_state} method, which can be called in a migration.
# For example, the following migration:
#
# ```
# class MyMigration < ActiveRecord::Migration[6.0]
#   def change
#     reversible do |o|
#       o.up do
#         Fl::Core::List::Db.register_list_item_state(1, 'selected', 'Selected (Normal)')
#         Fl::Core::List::Db.register_list_item_state(2, 'deselected', 'Deselected')
#       end
#
#       o.down do
#       end
#     end
#   end
# end
# ```
#
# registers the standard list item states.

module Fl::Core::List::Db
  # extend ActiveSupport::Concern

  # Register a list item state.
  # This method inserts a row in the table that contains all known list item states.
  # If a row with identifier *sid* or name *name* is already present, no attempt is made to insert one.
  #
  # @param sid [Integer] The unique identifier for the state.
  # @param name [String] The corresponding (and also unique) name.
  # @param desc [String] A description of the state; for human consumption.
  #
  # @raise Raises an exception if it fails to exdcute the database call.
  
  def self.register_list_item_state(sid, name, desc)
    c = Fl::Core::List::BaseItem.connection

    w = Fl::Core::List::BaseItem.sanitize_sql_for_conditions([ "((id = :sid) OR (name = :name))",
                                                               { sid: sid, name: name } ])
    sql = "SELECT id, name FROM fl_core_list_item_state_t WHERE #{w}"
    r = c.execute(sql)

    if r.count == 0
      c.execute <<-SQL
        INSERT INTO fl_core_list_item_state_t (id, name, desc_backstop)
          VALUES (#{sid}, '#{name}', '#{desc}');
        SQL
    end
  end

  # Perform actions when the module is included.

  #included do
  #end
end
