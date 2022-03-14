module Fl::Core::List::Permission
  # The **:manage_list_items** permission class.
  # This permission grants actors the ability to add or remove items in a list.
  
  class ManageItems < Fl::Core::Access::Permission
    # The permission name.
    NAME = :manage_list_items

    # dependent permissions granted by **:manage_list_items**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
      super(NAME, GRANTS)
    end
  end
end
