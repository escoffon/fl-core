module Fl::Core::Access
  # The base class for permission checkers.
  # A permission checker implements an algorithm for checking if an actor has been granted a requested
  # permission on an object (which will be referred to as an *asset*).
  #
  # Note that checker methods typically are not invoked directly, but rather through methods that
  # were injected by the {Fl::Core::Access::Access::ClassMacros#has_access_control} macro.
  
  class Checker
    # Initializer.

    def initialize()
      super()
    end

    # Configure the including class.
    # The access control macro {Fl::Core::Access::Access::ClassMacros#has_access_control} calls
    # this method in its implementation.
    # Use it to perform checker-specific configuration of the including class (for example, to inject
    # instance methods to manage access rights).
    #
    # @param base [Class] The class object in whose context the `has_access_control` macro is executed.

    def configure(base)
    end
    
    # Run an access check.
    # This method implements the algorithm to check if *actor* has been granted permission *permission*
    # on object *asset*. For example, to check if user `u1` has **:read** access to file asset *a*,
    # you call this method as follows.
    #
    # ```
    # u1 = get_user()
    # a = get_file_asset()
    # c = get_checker_instance()
    # granted = c.access_check(:read, u1, a)
    # ```
    #
    # Note that the method signature accepts string (fingerprint or GlobalID) values for *actor* and *assets*.
    # This is useful in situations where the method is called directly from a checker instance, rather than
    # indirectly from a {Fl::Core::Access::Access::InstanceMethods#has_permission?}.
    # For example, say we have defined a community model
    # `Community` that manages a list of members `Community::Member`; the permissions granted to each member
    # is stored in the `Community::Member` instance. In that situation, the `Community` checker accepts actor
    # (the potential member) and asset (the community) as fingerprints as well as objects, so that a client can
    # optimize the fetch of the permission information by passing fingerprints directly, rather than first
    # getting actor or asset objects.
    #
    # The default implementation is rather restrictive: it simply returns `nil` to indicate that
    # no access has been granted. Subclasses are expected to override it.
    #
    # This method is called from {Fl::Core::Access::Access::ClassMethods#has_permission?}
    # or {Fl::Core::Access::Access::InstanceMethods#has_permission?}, and typically is not called directly
    # by a client.
    #
    # In cases where *asset* is a class object, the permission is granted (or denied) at the class level.
    # For example, {Fl::Core::Access::Permission::Index} applies to getting a list of objects by executing
    # a query via a call to a class method, whereas {Fl::Core::Access::Permission::Read} controls access
    # to an instance, and therefore applies to instance methods.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The requested permission.
    #  See {Fl::Core::Access::Helper.permission_name}.
    # @param actor [Object,String] The actor requesting *permission*.
    #  Implementations may accept string values, which should be object fingerprints or GlobalIDs.
    # @param asset [Object,Class,String] The target of the request (the asset for which *permission* is requested).
    #  Implementations may accept string values, which should be object fingerprints or GlobalIDs.
    # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
    #  checker parameter.
    #
    # @return [Boolean,nil] An access check method is expected to return a boolean value `true` if access
    #  rights were granted, and `false` if access rights were denied.
    #  Under some conditions, it may elect to return `nil` to indicate that there was some kind of error
    #  when checking for access; a `nil` return value indicates that access rights were not granted,
    #  and it *must* be interpreted as such.

    def access_check(permission, actor, asset, context = nil)
      return false
    end

    protected
    
    # Get the name of a permission.
    # This is just a wrapper for {Fl::Core::Access::Helper.permission_name}, provided here as
    # a convenience for subclasses.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The permission whose name
    #  to get.
    #
    # @return [Symbol,nil] Returns the permission name if it can resolve it; otherwise, it returns `nil`.
    
    def permission_name(permission)
      Fl::Core::Access::Helper.permission_name(permission)
    end
  end
end
