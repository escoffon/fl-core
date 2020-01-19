module Fl::Core::Access
  # A null permission checker: all requests are approved.
  # This checker is used occasionally to override stricter access checks in individual class instances.
  # It goes without saying that it is a dangerous checker, and should be used sparingly.
  
  class NullChecker < Checker
    # Initializer.

    def initialize()
      super()
    end
    
    # Run an access check.
    # This implementation returns `true`, thereby always granting access rights.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission] The requested permission;
    #  this is usually the name of a permission registered with the permission registry, but it could
    #  also be passed as a permission instance.
    # @param actor [Object] The actor requesting *permission*.
    # @param asset [Object] The target of the request (the asset for which *permission* is requested).
    # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
    #  checker parameter.
    #
    # @return [Boolean] Returns `true` unconditionally: all requests are granted.

    def access_check(permission, actor, asset, context = nil)
      return true
    end
  end
end
