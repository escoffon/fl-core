require 'fl/core/access'

module Fl::Core::Actor
  # Permissions defined by the actor package.

  module Permission
    # The **:manage_actor_group_members** permission class.
    # This permission grants actors the ability to add or remove members in a group.
  
    class ManageMembers < Fl::Core::Access::Permission
      # The permission name.
      NAME = :manage_actor_group_members

      # The permission bit.
      BIT = 0x00000080

      # dependent permissions granted by **:manage_actor_group_members**.
      GRANTS = [ ]

      # Initializer.
      def initialize()
        super(NAME, BIT, GRANTS)
      end
    end
  end
end
