# Tables for storing lists and list items
    
class CreateFlCoreLists < ActiveRecord::Migration[6.0]
  def change
    # Lists
    
    create_table :fl_core_lists do |t|
      # The type name, for STI. We add STI support so that clients of the gem can extend the table and
      # create list subclasses.
      t.string		:type, null: false, index: { name: :fl_core_list_type_idx }

      # The title and caption for the list
      # :caption_html is the HTML representation of the caption, and :caption_json the JSON representation
      # (which is expected to be in Prosemirror format)
      t.string		:title
      t.text		:caption_html
      t.text		:caption_json

      # The list owner; typically this is a user, but we define a polymorphic association for flexibility
      # The owner_fingerprint attribute is an optimization for query support
      t.references	:owner, polymorphic: true, index: { name: :fl_core_list_owner_idx }
      t.string		:owner_fingerprint, index: { name: :fl_core_list_owner_fp_idx }

      # Are new items readonly by default
      t.boolean		:default_item_state_locked

      # Stores the JSON representation of the display preferences for the list
      t.text		:list_display_preferences

      t.timestamps
    end

    # The known states for a list item
    # Clients of the gem can register additional states if desired, and they will be picked up by the code
    
    create_table :fl_core_list_item_state_t do |t|
      # Rails needs to convert this into symbols in the runtime
      t.string		:name

      # and this is a backstop value if the translation is not found in Rails
      t.text		:desc_backstop
    end
    
    # List items; the table provides storage for a many-to-many association
    
    create_table :fl_core_list_items do |t|
      # The type name, for STI. We add STI support so that clients of the gem can extend the table and
      # create list item subclasses.
      t.string		:type, null: false, index: { name: :fl_core_list_item_type_idx }

      # The list. We use a regular reference, which mostly works, but causes problems with the association's
      # `create` method. (Not sure what triggers it, but the STI structure of the list table seems to confuse
      # the association.) Using a polymorphic association does not quite make sense, and additionally it seems
      # to cause all hell to break loose
      t.references	:list, index: { name: :fl_core_l_i_list_idx }

      # The listed object; polymorphic since lists can hold heterogeneous collections
      # The fingerprint is a query optimizer
      t.references	:listed_object, polymorphic: true, index: { name: :fl_core_l_i_lo_idx }
      t.string		:listed_object_fingerprint, index: { name: :fl_core_l_i_lo_fp_idx }

      # We may need an additional class name field in situations when the listed object is an instance of
      # a subclass in a hierarchy of listable objects. (For example, a reminder is a subclass of a calendar
      # item, and the listable extensions are in the latter rather than the former, so that the :listed_object
      # refrence uses the calendar item class name.)
      t.string		:listed_object_class_name, index: { name: :fl_core_l_i_lo_cn_idx }

      # The item owner; typically this is a user, but we define a polymorphic association for flexibility
      # The fingerprint is a query optimizer
      t.references	:owner, polymorphic: true, index: { name: :fl_core_l_i_own_idx }
      t.string		:owner_fingerprint, index: { name: :fl_core_l_i_own_fp_idx }

      # The name of the list item.
      # Used to identify list items by path; must also be unique for a given list (currently enforced
      # at the ActiveRecord model level)
      t.string		:name

      # The state of the item; note that an item can be in different states in different lists
      # - the state value: 1) selected, 2) deselected.
      #   Subclasses can extend this list by adding records to fl_core_list_item_state_t
      # - a note associated with the update
      # - when it was last set
      # - who set it; polymorphic for flexibility
      # - a flag to lock the object state
      t.integer		:state
      t.text		:state_note
      t.datetime	:state_updated_at
      t.references	:state_updated_by, polymorphic: true, index: { name: :fl_core_l_i_state_uby_idx }
      t.boolean		:state_locked

      # Sort order; used to create ordered lists
      t.integer		:sort_order

      # A number of denormalizations done so that queries can sort by listed object properties without
      # creating a join

      # the list item's summary (from the listed object)
      t.string		:item_summary, index: { name: :fl_core_l_i_summary_idx }

      # the creation and modification times fro the listed object
      t.datetime	:listed_object_created_at, precision: 6, index: { name: :fl_core_l_i_lo_c_at_idx }
      t.datetime	:listed_object_updated_at, precision: 6, index: { name: :fl_core_l_i_lo_u_at_idx }
      
      t.timestamps
    end

    reversible do |o|
      o.up do
        db_cfg = ActiveRecord::Base.configurations[Rails.env]

        # The current known item states
        Fl::Core::List::Db.register_list_item_state(1, 'selected', 'Selected (Normal)')
        Fl::Core::List::Db.register_list_item_state(2, 'deselected', 'Deselected')

        # constraints of the list item association table

        if db_cfg['adapter'] != 'sqlite3'
          execute <<-SQL
            ALTER TABLE fl_core_list_items
            ADD CONSTRAINT fl_core_list_items_list_fk FOREIGN KEY (list_id) REFERENCES fl_core_lists(id)
          SQL

          execute <<-SQL
            ALTER TABLE fl_core_list_items
              ADD CONSTRAINT fl_fmwk_list_items_sta_fk FOREIGN KEY (state) REFERENCES fl_core_list_item_state_t(id)
          SQL
        end
      end

      o.down do
      end
    end
  end
end
