class CreateActorGroups < ActiveRecord::Migration[6.0]
  def change
    # The actor groups known to the system.
    
    create_table :fl_core_actor_groups do |t|
      # The group name; no index here since we query the lowercase value (and create the index later)
      t.string		:name

      # A note about the group; for example, for the group description
      t.text		:note

      # The entity that owns the group; typically this is a user, but we define a polymorphic association
      # for flexibility
      # The owner_fingerprint attribute is an optimization for query support
      t.references	:owner, polymorphic: true, index: { name: :fl_core_act_grp_owner_idx }
      t.string		:owner_fingerprint, index: { name: :fl_core_act_grp_owner_fp_idx }

      t.timestamps
    end
    
    # The actor group membership list.
    
    create_table :fl_core_actor_group_members do |t|
      # A title to associate with the member (like a nickname, for example)
      t.string		:title

      # A note about the member
      t.text		:note

      # The group.
      t.references	:group, index: { name: :fl_core_grp_memb_group_idx }

      # The actor member
      # The actor_fingerprint attribute is an optimization for query support
      t.references	:actor, polymorphic: true, index: { name: :fl_core_grp_memb_actor_idx }
      t.string		:actor_fingerprint, index: { name: :fl_core_grp_memb_actor_fp_idx }

      t.timestamps
    end
    
    reversible do |o|
      o.up do
        execute "CREATE UNIQUE INDEX fl_core_act_grp_name_u_idx ON fl_core_actor_groups(lower(name))"

        # The built-in public group is a special group used mostly to grant permissions on assets to all
        # actors in the system

        Fl::Core::Actor::Group.create(name: Fl::Core::Actor::Group::PUBLIC_GROUP_NAME,
                                      note: 'Public group')
        say "created the public group"
      end

      o.down do
        execute "DROP INDEX fl_core_act_grp_name_u_idx"
      end
    end
  end
end
