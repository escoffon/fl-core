require 'fl/core/access'

module Fl::Core::Comment
  # Permissions defined by the comment package.

  module Permission
    # The **:index_comments** permission class.
    # This permission grants actors the ability to list the comments associated with an object.
  
    class IndexComments < Fl::Core::Access::Permission
      # The permission name.
      NAME = :index_comments

      # dependent permissions granted by **:index_comments**.
      GRANTS = [ ]

      # Initializer.
      def initialize()
        super(NAME, GRANTS)
      end
    end

    # The **:create_comments** permission class.
    # This permission grants actors the ability to create comments associated with an object.
  
    class CreateComments < Fl::Core::Access::Permission
      # The permission name.
      NAME = :create_comments

      # dependent permissions granted by **:create_comments**.
      GRANTS = [ ]

      # Initializer.
      def initialize()
        super(NAME, GRANTS)
      end
    end
  end
end
