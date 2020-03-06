module Fl::Core
  # Test checker.
  # Uses a local hash of object/actor permissions.
  
  class TestCheckerOne < Fl::Core::Access::Checker
    # Initializer.
    #
    # @param grants [Array] The grants. Each element is a two-element array that contains an object and a list
    #  of grants. This list is an array whose elements are also two-element arrays containing an actor and a list of
    #  permissions granted.
    
    def initialize(grants = [ ])
      @_grants = _initialize_grants(grants)
      
      super()
    end

    # Reload the grants.
    # This way the grants can be customized.
    #
    # @param grants [Array] The grants. Each element is a two-element array that contains an object and a list

    def grants=(g)
      @_grants = _initialize_grants(g)
    end
    
    # Run an access check.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The requested permission.
    #  See {Fl::Core::Access::Helper.permission_name}.
    # @param actor [Object] The actor requesting *permission*.
    # @param asset [Object,Class] The target of the request (the asset for which *permission* is requested).
    # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
    #  checker parameter.
    #
    # @return [Boolean,nil] An access check method is expected to return a boolean value `true` if access
    #  rights were granted, and `false` if access rights were denied.
    #  Under some conditions, it may elect to return `nil` to indicate that there was some kind of error
    #  when checking for access; a `nil` return value indicates that access rights were not granted,
    #  and it *must* be interpreted as such.

    def access_check(permission, actor, asset, context = nil)
      asset_grants = @_grants[asset.fingerprint]
      return false if asset_grants.nil?

      actor_grants = asset_grants[actor.fingerprint]
      return false if actor_grants.nil?

      m = Fl::Core::Access::Helper.permission_mask(permission)
      return false if m == 0
      ((actor_grants & m) == m)
    end

    protected
    
    private

    def _initialize_grants(grants)
      grants.reduce({ }) do |acc1, e1|
        k1 = e1[0].fingerprint
        acc1[k1] = e1[1].reduce({ }) do |acc2, e2|
          k2 = e2[0].fingerprint
          acc2[k2] = e2[1].reduce(0) do |acc3, e3|
            acc3 |= Fl::Core::Access::Helper.permission_mask(e3)
            acc3
          end
          acc2
        end

        acc1
      end
    end
  end
end
