module Fl::Core::Access
  # The base class for permissions.
  # This class contains the core functionality for permission descriptors; subclasses, when used,
  # are typically just namespaces and don't add or modify functionality.
  # For example:
  #
  # ```
  # class MyPermission < Fl::Core::Access::Permission
  #  NAME = :my_permission
  #  BIT = 0x00000010
  #  GRANTS = [ Fl::Core::Access::Permission::Read::NAME ]
  #
  #  def initialize(ext)
  #    @ext = ext
  #    super(NAME, BIT, GRANTS)
  #  end
  #
  #  attr_reader :ext
  # end
  #
  # myp = MyPermission.new('additional data').register()
  # ```
  # The `MyPermission.new.register` call registers `MyPermission` with the permission registry.
  #
  # #### Simple and cumulative (forwarding) permissions
  #
  # There are two types of permissions. A *simple* permission describes an atomic grant, like `read` or
  # `write`; these permissions define a bit value and have an empty grants array.
  # A permission can also grant other permissions by listing them in the constructor's *grants* argument;
  # we call this a *forwarding* permission.
  # In this case, the bit value is 0, and there is a nonempty *grants* array; the permission mask for
  # forwarding permissions is the ORed value of permission masks from the grants.
  # Access checkers need to consider this "forwarding" of grants when determining if an actor has
  # access to a given asset; they do so by using the permission's {#permission_mask} rather than the
  # {#bit}. (Actually typically a checker would use the class method {.permission_mask} instead.
  # For example, the standard {Permission::Edit} permission defines *grants* to have value
  # `[ :read, :write ]`; an access checker for the **:write** permission should grant access if
  # **:edit** is granted.
  #
  # Use the class methods {.permission_mask}, {.permission_grantors}, {.grantors_for_permission} to
  # support forwarded access checks.
  #
  # #### Standard permission classes
  #
  # The following permission classes are registered:
  #
  # - {Permission::Owner} grants ownership.
  # - {Permission::Read} grants read only access.
  # - {Permission::Write} grants write only access.
  # - {Permission::Delete} grants delete only access.
  # - {Permission::Index} grants index access.
  # - {Permission::Edit} grants read and write access to assets.
  # - {Permission::Manage} grants read, write, and delete access to assets.

  class Permission
    # Exception raised when a permission name is doubly registered.

    class Duplicate < RuntimeError
      # Initializer.
      #
      # @param permission [Fl::Core::Access::Permission] The duplicate permission.
      # @param msg [String] Message to pass to the superclass implementation.
      #  If `nil`, a standard message is created from the permission name.

      def initialize(permission, msg = nil)
        @permission = permission
        msg = I18n.tx('fl.core.access.permission.duplicate',
                      name: permission.name, bit: permission.bit,
                      class_name: permission.class.name) unless msg.is_a?(String)
        super(msg)
      end

      # The duplicate permission.
      # @return [Fl::Core::Access::Permission] Returns the *permission* argument to the constructor.

      attr_reader :permission
    end

    # Exception raised when a permission name is not registered.

    class Missing < RuntimeError
      # Initializer.
      #
      # @param name [Symbol,String] The missing permission name.
      # @param msg [String] Message to pass to the superclass implementation.
      #  If `nil`, a standard message is created from the permission name.

      def initialize(name, msg = nil)
        @name = name.to_sym
        msg = I18n.tx('fl.core.access.permission.missing', name: name) unless msg.is_a?(String)
        super(msg)
      end

      # The name of the permission.
      # @return [Symbol] Returns the name of the permission.

      attr_reader :name
    end
    
    @_permission_registry = {}
    @_permission_grants = nil
    @_permission_masks = nil

    # Get the permission name for this class.
    # Each registered class must have a unique name.
    #
    # @return [Symbol] Returns the name of the permission implemented by this class.

    def self.name()
      @_permission_name
    end
    
    # Register a permission object.
    # This method is called by the instance method {#register}.
    #
    # @param permission [Fl::Core::Access::Permission] The permission to register.
    #
    # @return [Fl::Core::Access::Permission] Returns *permission*.
    #
    # @raise [Fl::Core::Access::Permission::Duplicate] Raised if *name* is already registered.

    def self.register(permission)
      k = permission.name.to_sym
      raise Fl::Core::Access::Permission::Duplicate.new(permission) if @_permission_registry.has_key?(k)

      b = permission.bit.to_i
      @_permission_registry.each do |k, p|
        raise Fl::Core::Access::Permission::Duplicate.new(permission) if p.bit == p
      end
        
      @_permission_registry[k] = permission

      # A registration invalidates the permission grants registry
      _invalidate_permission_grants()

      permission
    end

    # Look up a permission in the registry.
    #
    # @param name [Symbol,String] The permission name.
    #
    # @return [Fl::Core::Access:Permission] Returns an instance of (a subclass of)
    #  {Fl::Core::Access:Permission} if *name* is registered, `nil` otherwise.
      
    def self.lookup(name)
      @_permission_registry[name.to_sym]
    end

    # Remove a permission from the registry.
    #
    # @param name [Symbol,String] The permission name.

    def self.unregister(name)
      n = name.to_sym
      if @_permission_registry.has_key?(n)
        p = @_permission_registry.delete(n)
      end

      # A deregistration invalidates the permission grants registry
      _invalidate_permission_grants()
    end

    # Return the names of all permissions in the registry.
    #
    # @return [Array<Symbol>] Returns an array containing the names of all currently registered
    #  permissions.
      
    def self.registered()
      @_permission_registry.map { |k, v| k.to_sym }
    end

    # Return the grantors for permissions in the registry.
    # Compound permissions (those with a nonempty {Permission#grants} array) include other permissions.
    # This method returns a map of the permissions that grant another one.
    #
    # @return [Hash] Returns a hash where the keys are permission names, and the values are arrays that
    #  list the other permissions that grant it.
      
    def self.permission_grantors()
      _permission_grants()
    end

    # Return the grantors for a given permission in the registry.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The permission whose grants
    #  to get. The value of this parameter is described in {Fl::Core::Access::Helper.permission_name}.
    #
    # @return [Array<Symbol>] Returns an array that lists the permission that grant *name*.
      
    def self.grantors_for_permission(permission)
      k = Fl::Core::Access::Helper.permission_name(permission)
      g = _permission_grants
      (g.has_key?(k)) ? g[k] : [ ]
    end

    # Return the permission mask for a given permission in the registry.
    # You should use this method to generate permission masks, rather than relying on the
    # {Permission#bit} attribute, since composite permissions set their bit value to 0, and use the
    # {Permission#grants} attribute to generate the permission bitmask.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The permission whose mask
    #  to get. The value of this parameter is described in {Fl::Core::Access::Helper.permission_name}.
    #
    # @return [Integer] Returns an integer containing the bitmask of all permissions granted by *permission*.
      
    def self.permission_mask(permission)
      k = Fl::Core::Access::Helper.permission_name(permission)
      m = _permission_masks
      (m.has_key?(k)) ? m[k] : 0
    end

    # Shows the grants in a permission mask.
    # Extracts the bits from *mask* and returns the corresponding simple permission name if one
    # is found.
    #
    # @param mask [Integer] An integer containing the permission mask.
    #
    # @return [Array<Symbol>] Returns an array containing the names of the simple permissions that are
    #  present in *mask*.

    def self.extract_permissions(mask)
      @_permission_registry.reduce([ ]) do |acc, pkv|
        pk, pv = pkv
        acc << pk if (mask & pv.bit) != 0
        acc
      end
    end
      
    # Initializer.
    #
    # @param name [Symbol,String] The name of the permission; this value must be unique for all
    #  permission instances.
    # @param bit [Integer] An integer whose value consists of all zeros except for a single bit that
    #  identifies the permission; this value must be unique for all permission instances.
    # @param grants [Array<Symbol,String,Fl::Core::Access::Permission,Class>] An array containing
    #  the list of other permissions that are also granted by *name*. For example, a **:manage** permission
    #  may grant **:read**, **:write**, and **:delete**. This list is used to build the permission mask
    #  to use when checking access.
    #  The element values are as described in {Fl::Core::Access::Helper.permission_name}.

    def initialize(name, bit, grants = [ ])
      @name = name.to_sym
      @bit = bit.to_i
      @grants = (grants.is_a?(Array)) ? grants.map { |g| Fl::Core::Access::Helper.permission_name(g) } : [ ]

      rv = super()
        
      self.class.instance_variable_set(:@_permission_name, name)

      rv
    end

    # The permission name.
    # @return [Symbol] Returns the name of the permission.

    attr_reader :name

    # The permission bit.
    # @return [Integer] Returns the permission bit.

    attr_reader :bit

    # The grants list.
    # This is the normalized value of the *grants* argument to {#initialize}, and it lists the permission
    # that this permission grants.
    # @return [Array<Symbol>] Returns the list of permissions granted by this permission.

    attr_reader :grants

    # Registers the instance with the permission registry.
    #
    # Note that, because this method calls {.register}, which in turn calls {#grants},
    # any permissions listed in *grants* must have already been registered.
    #
    # @return [Fl::Core::Access::Permission] Returns `self`.
    #
    # @raise [Fl::Core::Access::Permission::Duplicate] Raised if *name* or *bit* are already registered.
    #
    # @raise [Fl::Core::Access::Permission::Missing] Raised if any of the permissions listed
    #  in *grants* are not yet registered.

    def register()
      Fl::Core::Access::Permission.register(self)
    end

    # Get the permission mask.
    # You should use {.permission_mask} instead of this method, since {.permission_mask} caches the value
    # of the permission mask so that it does not need to be recalculated.
    #
    # @return [Integer] Returns an integer that contains the ORed permission masks from all grants.
    #  This value contains the set of all permission that this permission grants.

    def permission_mask()
      self.grants.reduce(self.bit) do |mask, g|
        p = Fl::Core::Access::Permission.lookup(g)
        mask |= p.permission_mask if p
        mask
      end
    end

    # Expand the permission grants.
    #
    # @return [Array,Fl::Core::Access::Permission>] Returns an integer that lists all the grants (direct and
    #  indirect) from *self*.
    #  This value contains the set of all permission that this permission grants.

    def expand_grants()
      found = [ ]
      self.grants.reduce([ ]) do |x, g|
        p = Fl::Core::Access::Permission.lookup(g)
        if p.grants.count < 1
          unless found.include?(p.name)
            x << p
            found << p.name
          end
        else
          p.expand_grants.each do |px|
            unless found.include?(px.name)
              x << px
              found << px.name
            end
          end
        end
        
        x
      end
    end
    
    # Get the grantor list.
    # This is the list of permission that grant this permission; it is the (global) reverse of the
    # {#grants} list.
    #
    # @return [Array<Symbol>] Returns the list of permissions that grant this permission.

    def grantors()
      Fl::Core::Access::Permission.grantors_for_permission(self.name)
    end

    private

    def self._invalidate_permission_grants()
      @_permission_grants = nil
      @_permission_masks = nil
    end

    def self._permission_grants()
      _rebuild_permission_grants unless @_permission_grants.is_a?(Hash)
      @_permission_grants
    end

    def self._rebuild_permission_grants()
      @_permission_grants = {}
      @_permission_registry.each do |pk, pv|
        _register_grants(pv.grants, pk)
      end

      # a bit hokey, but we need to remove spurious grants to self that may have been (well, were...)
      # introduced by _register_grants

      @_permission_grants.each { |gk, gv| gv.delete(gk) }
      
      @_permission_grants
    end

    def self._register_grants(gl, pn)
      @_permission_grants[pn] = [ ] unless @_permission_grants.has_key?(pn)
      @_permission_grants[pn] |= [ pn ]
      gl.each do |gn|
        @_permission_grants[gn] |= [ pn ]
        gp = lookup(gn)
        _register_grants(gp.grants, pn) if gp && (gp.grants.count > 0)
      end
    end

    def self._permission_masks()
      _rebuild_permission_masks unless @_permission_masks.is_a?(Hash)
      @_permission_masks
    end

    def self._rebuild_permission_masks()
      @_permission_masks = {}
      @_permission_registry.each do |pk, pv|
        @_permission_masks[pk] = pv.permission_mask
      end
      
      @_permission_masks
    end
  end

  # The **:owner** permission class.
  # This permission grants ownership rights to an object.
  # It is used to create a record that marks an actor as the "owner" of an asset; this record is essential
  # in permission queries that return lists of assets visible to a given actor.
  
  class Permission::Owner < Permission
    # The permission name.
    NAME = :owner

    # The permission bit.
    BIT = 0x00000001

    # dependent permissions granted by **:owner**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Owner.new.register

  # The **:create** permission class.
  # This permission grants the ability to create assets (typically of a specific class).
  
  class Permission::Create < Permission
    # The permission name.
    NAME = :create

    # The permission bit.
    BIT = 0x00000002

    # dependent permissions granted by **:create**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Create.new.register

  # The **:read** permission class.
  # This permission grants read only access to assets.
  
  class Permission::Read < Permission
    # The permission name.
    NAME = :read

    # The permission bit.
    BIT = 0x00000004

    # dependent permissions granted by **:read**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Read.new.register

  # The **:write** permission class.
  # Note that this permission grants write only access to assets; for read and write access,
  # use {#Permission::Edit}.
  
  class Permission::Write < Permission
    # The permission name.
    NAME = :write

    # The permission bit.
    BIT = 0x00000008

    # dependent permissions granted by **:write**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Write.new.register

  # The **:delete** permission class.
  # This permission grants delete only access to assets; for additional read and write access,
  # use {#Permission::Manage}.
  
  class Permission::Delete < Permission
    # The permission name.
    NAME = :delete

    # The permission bit.
    BIT = 0x00000010

    # dependent permissions granted by **:delete**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Delete.new.register

  # The **:index** permission class.
  # This permission grants index only access to assets, which controls if the children of an asset can
  # be listed.
  
  class Permission::Index < Permission
    # The permission name.
    NAME = :index

    # The permission bit.
    BIT = 0x00000020

    # dependent permissions granted by **:index**.
    GRANTS = [ ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Index.new.register

  # The **:edit** permission class.
  # This permission grants read and write access to assets.
  
  class Permission::Edit < Permission
    # The permission name.
    NAME = :edit

    # The permission bit.
    BIT = 0x00000000

    # dependent permissions granted by **:edit**.
    GRANTS = [ :read, :write ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Edit.new.register

  # The **:manage** permission class.
  # This permission grants read, write, and delete access to assets.
  
  class Permission::Manage < Permission
    # The permission name.
    NAME = :manage

    # The permission bit.
    BIT = 0x00000000

    # dependent permissions granted by **:manage**.
    GRANTS = [ :edit, :delete ]

    # Initializer.
    def initialize()
     super(NAME, BIT, GRANTS)
    end
  end

  Permission::Manage.new.register
end
