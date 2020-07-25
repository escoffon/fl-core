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
      return unless plist.is_a?(Array)
      
      # Since there is no unregister method, we have to do the cleanup through direct manipulations of the registry:
      # 1. get a list of current permissions, sorted by bit value.

      p_list = Fl::Core::Access::Permission.registered.map { |n| Fl::Core::Access::Permission.lookup(n) }
      p_sorted = p_list.sort do |p1, p2|
        if p1.bit == 0
          (p2.bit == 0) ? 0 : 1
        elsif p2.bit == 0
          (p1.bit == 0) ? 0 : -1
        else
          p1.bit <=> p2.bit
        end
      end

      # 2. remove the ones in plist

      nlist = plist.map { |n| n.to_sym }
      p_filtered = p_sorted.reduce([ ]) do |acc, p|
        acc.push(p) unless nlist.include?(p.name.to_sym)
        acc
      end

      # 3. reset the registry

      Fl::Core::Access::Permission.instance_variable_set(:@_permission_registry, {})
      Fl::Core::Access::Permission.instance_variable_set(:@_permission_locations, {})
      Fl::Core::Access::Permission.instance_variable_set(:@_permission_grants, nil)
      Fl::Core::Access::Permission.instance_variable_set(:@_permission_masks, nil)
      Fl::Core::Access::Permission.instance_variable_set(:@_current_bit, 0)

      # 4. reregister the permissions

      p_filtered.each do |p|
        Fl::Core::Access::Permission.register(p)
      end
    end
  end
end
