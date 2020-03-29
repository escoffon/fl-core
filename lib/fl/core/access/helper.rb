module Fl::Core::Access
  # Helpers for the access module.
  
  module Helper
    # Enable access control support for a class.
    # Use this method to add access control support to an existing class:
    #
    # ```
    # class TheClass
    #   # class definition
    # end
    #
    # class MyAccessChecker < Fl::Core::Access::Checker
    #   def access_check(permission, actor, asset, context = nil)
    #     return access_check_algorithm_value
    #   end
    # end
    #
    # Fl::Core::Access::Helper.add_access_control(TheClass, MyAccessChecker.new, owner: :my_owner_method)
    # ```
    # This method is idempotent: if the class has already enabled access control, the operation is not performed.
    #
    # @param klass [Class] The class object where access control is enabled.
    # @param checker [Fl::Core::Access::Checker] The checker to use for access control.
    # @param cfg [Hash] A hash containing configuration parameters. See the documentation for
    #  {Fl::Core::Access::Access::ClassMacros.has_access_control}.

    def self.add_access_control(klass, checker, *cfg)
      unless klass.has_access_control?
        klass.send(:include, Fl::Core::Access::Access)
        klass.send(:has_access_control, checker, *cfg)
      end
    end

    # Get a permission.
    # If the *permission* argument is a string or a symbol, it is looked up in the permission registry.
    # If it is an instance of {Fl::Core::Access::Permission}, it is returned as is.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission] The permission to get.
    #
    # @return [Fl::Core::Access::Permission,nil] Returns the permission if it can resolve it;
    #  otherwise, it returns `nil`.
    
    def self.permission(permission)
      if permission.is_a?(Fl::Core::Access::Permission)
        permission
      elsif permission.is_a?(Symbol) | permission.is_a?(String)
        Fl::Core::Access::Permission.lookup(permission)
      else
        nil
      end
    end

    # Get the name of a permission.
    # If the *permission* argument is a string or a symbol, it is returned as a symbol.
    # If it is an instance of {Fl::Core::Access::Permission}, its
    # {Fl::Core::Access::Permission#name} is returned.
    # Otherwise, if it is a class, the method checks if it is a subclass of
    # {Fl::Core::Access::Permission}, and if so it returns its {Fl::Core::Access::Permission.name}
    # value.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The permission whose name
    #  to get.
    #
    # @return [Symbol,nil] Returns the permission name if it can resolve it; otherwise, it returns `nil`.
    
    def self.permission_name(permission)
      case permission
      when Symbol
        permission
      when String
        permission.to_sym
      when Fl::Core::Access::Permission
        permission.name
      when Class
        sc = permission
        until sc.nil?
          return permission.name if sc.name == Fl::Core::Access::Permission.name
          sc = sc.superclass
        end

        nil
      else
        nil
      end
    end

    # Build the permission mask from a list of permissions.
    # Combines the individual permissions' permission masks into a single one by ORing them.
    # The method also takes a single integer, which is returned as is, as a convenience.
    #
    # @param permission [Integer,Array<Integer,Symbol,String,Fl::Core::Access::Permission,Class>] The
    #  permissions whose masks to combine. An integer value is returned as is.
    #  Each element in the array is converted to a permission name as documented
    #  for {.permission_name}, and the permission mask obtained from the registry.
    #  If the element is an integer, it is used as is.
    #
    # @return [Integer] Returns the permission mask.
    
    def self.permission_mask(permission)
      pl = (permission.is_a?(Array)) ? permission : [ permission ]
      pl.reduce(0) do |mask, e|
        if e.is_a?(Integer)
          mask |= e
        else
          n = self.permission_name(e)
          mask |= Fl::Core::Access::Permission.permission_mask(n)
        end
        mask
      end
    end

    # Build a list of permission names from a list of permissions.
    #
    # @param plist [Array<Symbol,String,Fl::Core::Access::Permission,Class>] The permissions whose names to
    #  extract.
    #  Each element in the array is converted to a permission name as documented for {.permission_name}.
    #  Any string or symbol values that do not map to a known permission are dropped.
    #  A `nil` value returns an empty array.
    #
    # @return [Array<String>] Returns the list of permission names.
    
    def self.permission_names(plist)
      return [ ] if plist.nil?

      plist = [ plist ] unless plist.is_a?(Array)
      plist.reduce([ ]) do |acc, p|
        n = self.permission_name(p)
        acc << n if !n.nil? && Fl::Core::Access::Permission.lookup(n)
        acc
      end
    end
  end
end
