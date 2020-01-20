module Fl::Core::Test
  # Helpers for testing access functionality.
  # Include this module to inject methods for use with (ideally [RSpec](https://rspec.info/)) test scripts:
  #
  # ```
  # RSpec.configure do |c|
  #   c.include Fl::Core::Test::AccessHelpers
  # end
  # ```
  
  module AccessHelpers
    # Cleanup the access control registry.
    # This method drops a given list of permissions from the permission registry.
    #
    # @param plist [Array<Symbol,String>] An array containing the registered names of permissions to
    #  drop. If *plist* is not an array, the method has no effect.
    
    def cleanup_permission_registry(plist)
      plist = [ ] unless plist.is_a?(Array)
      plist.each { |p| Fl::Core::Access::Permission.unregister(p) }
    end
  end
end
