module Fl::Core
  # A module to provide mixins for converting an object to a hash.
  # The API implemented by this module introduces the notion of an _actor_: this is the entity that makes
  # the request to build hash representations of an object. The framework itself does not define a specific
  # class for actors, but it assumes that the framework implementations are aware of its properties and
  # behave accordingly. (The framework code more or less passes the actor arguments down to the specific
  # implementations.)
  # A typical implementation of an actor is the object that stores and manages user information.

  module ModelHash
    # The methods in this module are installed as class method of an including class.

    module ClassMethods
    end

    # The methods in this module are installed as instance method of an including class.

    module InstanceMethods
      # Build a Hash representation of the object.
      # This method returns a Hash that contains key/value pairs that describe the object.
      #
      # This method first calls {#to_hash_options_for_verbosity} and merges its return value with +opts+.
      # It then builds the list of keys to place in the hash, based on the values in the merged options
      # and a call to {#to_hash_mandatory_keys_for_verbosity}.
      # Then, it calls {#to_hash_base} to generate an initial base representation, and
      # then  merges the value returned by {#to_hash_local} into the hash.
      # Subclasses override {#to_hash_local} to add their own additional properties, like this:
      #
      # ```
      #   def to_hash_local(actor, keys, opts = {})
      #     {
      #       :my_key => self.my_value
      #     }
      #   end
      # ```
      # If a group of objects has common base values, you can override the base method ({#to_hash_base});
      # in that case, it's probably best to chain a call to the original implementation.
      # See {#to_hash_base} for details.
      #
      # The following keys are placed in the list of keys to return:
      #
      # - **:type** in all cases.
      # - **:virtual_type** optionally by some classes that define a "virtual" type name; see below for a
      #   discussion of virtual types.
      # - **:id** if the object responds to `id`.
      # - **:global_id** the [GlobalID](https://github.com/rails/globalid) for the object, if it
      #   responds to `to_global_id`. (All ActiveRecord instances do.)
      # - **:api_root** the root path for the Rails API to the object's class.
      #   For example, an instance of My::Mod::MyObject by default sets the value to `/my/mod/my_objects`.
      #   Subclasses that use a different API signature need to override {#to_hash_api_root}.
      # - **:fingerprint** The object's fingerprint; if the object responds to **:fingerprint**, it is the
      #   return value from that method. Otherwise, the return value is the concatenation of the class
      #   name and object identifier, joined by a slash (/); this happens to be the default implementation
      #   for ActiveRecord objects. If the object does not respond to **:id**, no fingerprint is generated.
      # - **:created_at** and **:updated_at** if the verbosity is not **:id**, and the object
      #   responds to +created_at+ and +updated_at+, respectively.
      # - **:permissions** if the verbosity is **:minimal**, **:standard**, **:verbose**, or **:complete**, the key
      #   is not in the except list, the object responds to
      #   {Fl::Core::Access::Access::InstanceMethods#has_access_control?}, and that method returns `true`.
      # Additional keys will be placed as determined by +opts+ and {#to_hash_options_for_verbosity}.
      #
      # If the **:verbosity** option is not present, the method behaves as if its value was set to **:standard**.
      #
      # #### Type and virtual type
      #
      # The **:type** keys is a string containing the (Ruby) class name of the object, and is used for object
      # instance lookups. Classes that want to declare themselves as a generic type for the purposes of an API
      # also define **:virtual_type** to contain the generic name. For example, the {Fl::Core::Comment} subsystem
      # supports ActiveRecord and Neo4j implementations of comments. A hashed ActiveRecord object sets **:type**
      # to `Fl::Core::Comment::ActiveRecord::Comment` (for {Fl::Core::Comment::ActiveRecord::Comment}), and
      # **:virtual_type** to `Fl::Core::Comment` to indicate
      # to APIs that it contains generic comment data. The Fl Javascript object manager uses **:virtual_type**
      # to create instances of `FlCoreComment` objects rather than `FlCoreCommentActiveRecordComment` as would
      # be expected from **:type**.
      #
      # @param actor [Object] The actor for which we are building the hash representation. Some
      #  objects may return different contents, based on the requesting actor.
      # @param opts [Hash] Options for the method; this is an object-specific set of options.
      #  The following options are considered to be standard and either processed the same way,
      #  or ignored, by the subclasses:
      #
      #  - **:as_visible_to** An actor object to use for access determination instead of _actor_; when
      #    this option is present, the return value will contain the "slice" of the object that is
      #    visible to the actor in **:as_visible_to**, as opposed to the actor in _actor_.
      #    This is useful for objects that present themselves differently to different entities that
      #    access them.
      #  - **:verbosity** A symbol describing the verbosity level for the generated hash; this option
      #    controls the list of attributes that are added to the return value. The following
      #    values are supported:
      #
      #    - **:id** emits enough information to fetch the object later (typically,
      #      this is the **:type**, and **:id** attributes, but it also includes **:fingerprint**, **:global_id**,
      #      and **:api_root** in many cases).
      #    - **:minimal** emits a minimal set of attributes.
      #    - **:standard** emits a typical (or standard) set.
      #    - **:verbose** a more complete set.
      #    - **:complete** the full set.
      #    - **:ignore** ignore the verbosity setting and build the list of keys in the hash representation
      #      based on the **:only** and **:except** options.
      #      The lists associated with each value are object-dependent, although **:id** typically returns
      #      **:type**, **:id**, **:fingerprint**, and **:global_id**.
      #      Since the value defaults to **:standard** if not specified, you can use the value **:ignore**
      #      to instruct the method to ignore the value of the verbosity when building the options
      #      hash and generating the key list.
      #  - **:only** An array containing the exact list of attributes to return.
      #    A scalar value is converted to a one-element array.
      #  - **:include** An array containing a list of attributes to include in addition to those that the
      #    code returns by default (based on the verbosity level).
      #    If the **:only** list is defined, this value is ignored: callers
      #    that specify **:only** can just as easily place the contents of **:include** there.
      #    A scalar value is converted to a one-element array.
      #  - **:except** An array containing a list of keys that will not be returned. This value
      #    is removed from the final list of keys after the **:only** and **:include** lists have been taken into
      #    consideration.
      #    A scalar value is converted to a one-element array.
      #  - **:permissions** Controls the list of permissions returned in the **:permissions** key.
      #    The value is an array of permission names to check.
      #    Defaults to `[ :read, :write, :delete, :index, :index_contents ]`.
      #  - **:image_sizes** An array listing the image sizes whose URLs are returned for objects that
      #    contain images (pictures, group avatars, user avatars, and so on).
      #  - **:to_hash** A Hash containing options to pass to nested calls to this method for other
      #    objects in the representation. The keys are attribute names, and the values are hashes
      #    containing the options to pass to {#to_hash}. For example, say that the +subobj+ attribute
      #    maps to an object of class Fl::Core::MyClass; in this case, +subobj+ is converted to
      #    a hash representation via a call to +self.subobj.to_hash+, which is passed the value of
      #    _actor_ and <tt>opts[:to_hash][:subobj]</tt>, if present.
      #
      # @return [Hash] Returns a hash containing the object representation.

      def to_hash(actor, opts = nil)
        opts = opts || {}

        # make sure the keys are symbols.

        t_opts = {}
        opts.each { |k, v| t_opts[k.to_sym] = v }

        # make sure verbosity is stored as a Symbol; it may have come from a controller, and been
        # stored as a String.

        if t_opts.has_key?(:verbosity) && t_opts[:verbosity]
          verbosity = t_opts[:verbosity].to_sym
          t_opts[:verbosity] = verbosity
        else
          verbosity = :standard
        end

        # when we initialize n_opts, we must ensure that the :only, :include, and :except values
        # have been normalized (which also copies the arrays). Otherwise, we may end up overwriting
        # constants returned by to_hash_options_for_verbosity

        n_opts = {}
        if verbosity != :ignore
          to_hash_options_for_verbosity(actor, verbosity, t_opts).each do |vk, vv|
            if (vk == :only) || (vk == :include) || (vk == :except)
              n_opts[vk] = to_hash_normalize_list(vv)
            else
              n_opts[vk] = vv
            end
          end
        end
        n_opts[:verbosity] = verbosity

        # We build the :only, :include, and :except lists by merging opts and n_opts
        # We ignore :only in opts if it is already present in n_opts. The only way that it could
        # be present is if :verbosity had been provided, and the initial hash for the verbosity
        # expressly set :only. In other words, if the subclass specifies the :only for a given
        # verbosity, we ignore the call override

        if !n_opts.has_key?(:only) && t_opts.has_key?(:only)
          n_opts[:only] = to_hash_normalize_list(t_opts[:only])
        end

        # :include is ignored if :only has contents. If you specify :only, you can place :include there.
        # If it is not ignored, then the call option's value is merged into the defaults.

        if !n_opts.has_key?(:only) || (n_opts[:only].length < 1)
          if t_opts.has_key?(:include)
            if n_opts.has_key?(:include)
              to_hash_normalize_list(t_opts[:include]).each do |e|
                n_opts[:include] << e unless n_opts[:include].include?(e)
              end
            else
              n_opts[:include] = to_hash_normalize_list(t_opts[:include])
            end
          end
        else
          n_opts.delete(:include)
        end

        # For :except, the call option's value is merged into the defaults.

        if t_opts.has_key?(:except)
          if n_opts.has_key?(:except)
            to_hash_normalize_list(t_opts[:except]).each do |e|
              n_opts[:except] << e unless n_opts[:except].include?(e)
            end
          else
            n_opts[:except] = to_hash_normalize_list(t_opts[:except])
          end
        end

        # All other call options are copied as-is, potentially overriding the defaults.

        t_opts.each do |vk, vv|
          if (vk != :only) && (vk != :include) && (vk != :except)
            n_opts[vk] = vv
          end
        end

        # Now that we have the merged options, let's build the list of keys that will be returned.
        # The keys :type, :id (if defined), :fingerprint (if available), :global_id (if available),
        # and :api_root are always present.
        # Also, :created_at, :updated_at, :permisison, are treated specially:
        # - :created_at and :updated_at are added for higher verbosity than :id, if the object responds
        #   to those two methods.
        # - :permissions are added for higher verbosity than :id, the key is not in the except list, the
        #   object responds to {Fl::Core::Access::Access::InstanceMethods#has_access_control?}, and that method
        #   returns `true`.

        l_only = n_opts.has_key?(:only) ? to_hash_normalize_list(n_opts[:only]) : []
        l_include = n_opts.has_key?(:include) ? n_opts[:include] : []
        l_except = n_opts.has_key?(:except) ? n_opts[:except] : []

        if (verbosity != :ignore) && (verbosity != :id) && (l_only.length < 1)
          l_include << :created_at if self.respond_to?(:created_at)
          l_include << :updated_at if self.respond_to?(:updated_at)

          if (verbosity != :id) && self.respond_to?(:has_access_control?) && self.has_access_control?
            l_include << :permissions
          end
        end

        c_keys = to_hash_id_keys()

        l_only.each do |e|
          c_keys << e if !l_except.include?(e) && !c_keys.include?(e)
        end
        l_include.each do |e|
          c_keys << e if !l_except.include?(e) && !c_keys.include?(e)
        end

        # one last thing: add the must-haves

        to_hash_mandatory_keys_for_verbosity(verbosity).each do |e|
          c_keys << e
        end

        rv = to_hash_base(actor, c_keys, n_opts)

        # We must remove the keys we added in to_hash_base.
        # However, we need to leave :permission in the list. Here's why:
        # `self` may have actually defined a :permissions attribute; in that case, it will want to hash its
        # value, rather than generating it from the permission checks, so we need to give it a chance to
        # override the base value. Note that a model that defines a :permissions attribute is unlikely to
        # (and should not) also inject access control

        l_keys = []
        remove = rv.keys - [ :permissions ]
        c_keys.each do |e|
          l_keys << e unless remove.include?(e)
        end

        to_hash_local(actor, l_keys, n_opts).each do |k, v|
          rv[k] = v
        end

        rv
      end

      # Support for generating hash representations: normalize attribute lists.
      # This method takes an array and converts all its elements into symbols; it is used to
      # normalize the **:only**, **:except**, and **:include** #to_hash parameters.
      #
      # @param alist The list of attribute names; pass an array, a single attribute, or @c nil.
      #
      # @return If +alist+ is an array, returns a copy of +alist+ where all elements have been
      #  converted to symbols. If a single attribute, returns an array containing the converted value.
      #  If +nil+, returns +nil+.

      def to_hash_normalize_list(alist)
        if alist.is_a?(Array)
          alist.map { |e| e.to_sym }
        elsif alist
          [ alist.to_sym ]
        else
          nil
        end
      end

      protected

      # Converts a date value to a ISO8601 string.
      # Datetime values should be placed in a hash using this method, so that generated representation use
      # a known standard. For example, [Moment](https://momentjs.com/) has deprecated nonstandard string
      # representations of dates, so using ISO8601 ensures that `to_hash` representation are robust when
      # parsed in Javascript.
      #
      # @param ts [Datetime,Time,ActiveRecord::TimeWithZone] The date to convert.
      #
      # @return [String,nil] Returns the ISO8601 string for *ts*, or `nil` if *ts* does not respond to `iso8601`.

      def to_hash_date(ts)
        return (ts.respond_to?(:iso8601)) ? ts.iso8601 : nil
      end

      # @!group Subclass overrides

      #  The hash representation code uses the Template Method pattern, where a framework method like
      #  #to_hash calls a number of methods that are meant to be overridden or extended by subclasses
      #  to provide the subclass-specific functionality.
      #  These customization methods are documented in this section.

      # Given a verbosity level, return predefined hash options to use.
      # This method is expected to return a hash containing any of the keys supported by
      # {Fl::ModelHash::InstanceMethods#to_hash}.
      # These will be merged with the corresponding values in the hash options, if any.
      # Therefore, the values returned here can be viewed as defaults for the given object type.
      #
      # @param actor [Object] The actor for which we are building the hash representation.
      #  See the documentation for {Fl::ModelHash::InstanceMethods#to_hash} and 
      #  {Fl::Core::ModelHash::InstanceMethods#to_hash_local}.
      # @param verbosity [Symbol] The verbosity level; see #to_hash.
      # @param opts [hash] The options that were passed to {#to_hash}.
      #
      # @return [Hash] Returns a hash as described in the method documentation.
      #
      # @raise This implementation raises an exception to force object classes to provide their own.

      def to_hash_options_for_verbosity(actor, verbosity, opts)
        raise "please implement #{self.class.name}#to_hash_options_for_verbosity"
      end

      # Given a verbosity level, return keys that **must** be placed in the hash.
      # This method is expected to return an array of keys that will be added to the list of keys
      # to return in the hash.
      #
      # @param verbosity [Symbol] The verbosity level; see #to_hash.
      #
      # @return [Array<Symbol>] Returns an array of keys; the array may be empty.
      #  The default implementation returns an empty array.

      def to_hash_mandatory_keys_for_verbosity(verbosity)
        return []
      end

      # Return the default list of operations for which to check permissions.
      # The return value for this method is used by {#to_hash_permission_list} to generate the **:permissions**
      # hash property.
      #
      # @return [Array<Symbol>] Returns an array of symbol values that list the operations for which to obtain
      #  permissions.
      #  The default implementation returns the array `[ :owner, :read, :write, :delete, :index, :index_contents ]`;
      #  subclasses may
      #  override to add subclass-specific operations.

      def to_hash_operations_list
        [ Fl::Core::Access::Permission::Owner::NAME,
          Fl::Core::Access::Permission::Read::NAME,
          Fl::Core::Access::Permission::Write::NAME,
          Fl::Core::Access::Permission::Delete::NAME,
          Fl::Core::Access::Permission::Index::NAME,
          Fl::Core::Access::Permission::IndexContents::NAME
        ]
      end

      # Get the root path of the Rails API.
      # The base implementation derives the root path from the class name.
      #
      # @return [String] Returns the root path of the Rails API for an object of the object's class.

      def to_hash_api_root()
        "/#{self.class.name.pluralize.underscore}"
      end

      # Base implementation of the class-specific hash method, in case classes do not override it.
      #
      # @param actor [Object] The actor for which we are building the hash representation. Some
      #  objects may return different contents, based on the requesting actor.
      #  See the documentation for {#to_hash}.
      # @param keys [Array<Symbol>] An array containing the list of keys to place in the hash.
      # @param opts [Hash] The options that were passed to #to_hash.
      #
      # @return [Hash] Returns an empty hash; subclasses override it to generate type-specific return values.

      def to_hash_local(actor, keys, opts)
        {}
      end
      
      # @!endgroup

      # @!group Utilities

      # This section contains methods used by the hash representation code, and exported for possible
      # use by the subclass override methods.
      # In general, these methods are not meant to be overridden; however, subclasses may override
      # #to_hash_base to implement specialized functionality. See the documentation for {#to_hash_base}
      # for details.

      # Get the list of keys for the **:id** verbosity.
      #
      # @return [Array<Symbol>] Returns an array containing the symbols **:type**, **:global_id**,
      #  **:api_root**, **:fingerprint**, and **:id** (if the object responds to the `id` method).

      def to_hash_id_keys()
        c_keys = [ :type, :api_root ]
        [ :id, :fingerprint ].each { |m| c_keys << m if self.respond_to?(m) }
        c_keys << :global_id if self.respond_to?(:to_global_id)
        c_keys
      end

      # Whitelist a list of keys.
      # This method filters out *keys* so that only the keys in {#to_hash_id_keys} and *whitelist*
      # are returned.
      #
      # @param keys [Array<Symbols>] The array of keys to whitelist.
      # @param whitelist [Array<symbol>] The whilelist of keys to user; obly elements of this list
      #  are returned.
      #
      # @return [Array<Symbol>] Returns an array containing the symbols returned by {#to_hash_id_keys}
      #  and those in *keys* that also appear in *whitelist*.

      def to_hash_whitelist_keys(keys, whitelist)
        use = to_hash_id_keys() | whitelist
        keys.select { |k| use.include?(k.to_sym) }
      end

      # Extract to_hash options and use default values if not present.
      #
      # @param opts [Hash, nil] A hash of options to extract.
      # @param defaults [Hash] Default options.
      #
      # @return [Hash] If _opts_ is not a Hash, the method returns a shallow copy of _defaults_; if non-nil,
      #  it returns a shallow copy of _opts_.

      def to_hash_opts_with_defaults(opts, defaults = nil)
        if opts.is_a?(Hash)
          opts.dup
        elsif opts.is_a?(ActionController::Parameters)
          opts.to_h
        elsif defaults.is_a?(Hash)
          defaults.dup
        else
          {}
        end
      end

      # Merge to_hash options into default values.
      #
      # @param opts [Hash, nil] A hash of options to merge into _defaults_. If the value is +nil+,
      #  the method returns a shallow copy of _defaults_.
      # @param defaults [Hash] Default options.
      #
      # @return [Hash] Returns _opts_ merged into _defaults_, or a copy of _defaults_.

      def to_hash_merge_opts(opts, defaults = {})
        if opts.is_a?(Hash)
          defaults.merge(opts)
        else
          defaults.dup
        end
      end

      # Generate a key list based on the defaults and the **:only**, **:include**, and **:except** options.
      # If **:only** is present, it is used as the starting list; otherwise, +defaults+ is used.
      # Then, the values in the **:include** array are added to the key list.
      # Finally, the values in the **:except** array are removed from the key list.
      #
      # @param defaults [Array<Symbol>] An array containing the default list of keys.
      # @param opts [Hash] A hash possibly containing the optional keys **:only**, **:include**, and **:except**.
      #
      # @return [Array<Symbol>] Returns the list of keys to place in the object hash.
      
      def to_hash_keys(defaults, opts = {})
        t = (opts.has_key?(:only)) ? opts[:only] : defaults
        t = [ t ] unless t.is_a?(Array)
        klist = t.map { |k| k.to_sym }

        if opts.has_key?(:include)
          o_inc = (opts[:include].is_a?(Array)) ? opts[:include] : [ opts[:include] ]
          o_inc.each do |k|
            sk = k.to_sym
            klist << sk unless klist.include?(sk)
          end
        end

        if opts.has_key?(:except)
          o_exc = (opts[:except].is_a?(Array)) ? opts[:except] : [ opts[:except] ]
          o_exc.each do |k|
            sk = k.to_sym
            klist.delete(sk)
          end
        end

        klist
      end

      # Generate a permission hash for `self`.
      #
      # @param actor [Object] The actor requesting the hash.
      # @param plist [Array<Symbol>] The list of permission names for which to check; if `nil`, the 
      #  value is obtained via a call to {#to_hash_operations_list}.
      #
      # @return [Hash] Returns a hash where the keys are permission names, and the values the permissions;
      #  a `false` or `nil` value indicates no permission.

      def to_hash_permission_list(actor, plist = nil)
        return { } if actor.nil? || !self.respond_to?(:has_permission?)
        
        plist = self.to_hash_operations_list unless plist.is_a?(Array)

        # see if *actor* is the owner of `self`; if so, all permissions are allowed

        is_owner = self.has_permission?(Fl::Core::Access::Permission::Owner::NAME, actor)

        if is_owner
          plist.reduce({ }) do |acc, p|
            psym = p.to_sym
            acc[psym] = true
            acc
          end
        else
          plist.reduce({ }) do |acc, p|
            psym = p.to_sym
            acc[psym] = self.has_permission?(psym, actor)
            acc
          end
        end
      end

      # Build the base Hash representation of the model.
      # This utility method loads the initial representation of the hash for the model.
      # If you override this method, you should either make sure that the new implementation
      # returns at least the key/value pairs from this method, or you should chain the old one:
      #   alias original_to_hash_base to_hash_base
      #   def to_hash_base(actor, keys, opts)
      #     rv = original_to_hash_base(actor, keys, opts)
      #     rv[:my_key] = my_value
      #     rv
      #   end
      #
      # @param actor [Object] The object for which we are building the hash representation. Some
      #  objects may return different contents, based on the requesting actor.
      #  See the documentation for {#to_hash}.
      # @param keys [Array<Symbol>] An array containing the list of keys to return in the hash.
      # @param opts [Hash] Options for the method; this is an object-specific set of options.
      #
      # @return [Hash] Returns a hash containing some or all of the following keys.
      #
      #  - **:type** The object type (the class name of the model, basically).
      #  - **:id** The object id, if the object responds to the `id` method.
      #  - **:global_id** the [GlobalID](https://github.com/rails/globalid) for the object, if it
      #    responds to `to_global_id`. (All ActiveRecord instances do.)
      #  - **:api_root** the root path for the Rails API to the object's class.
      #    For example, an instance of My::Mod::MyObject by default sets the value to `/my/mod/my_objects`.
      #    Subclasses that use a different API signature need to override {#to_hash_api_root}.
      #  - **:fingerprint** The object's fingerprint; if the object responds to **:fingerprint**, it is the
      #    return value from that method. Otherwise, the return value is the concatenation of the class
      #    name and object identifier, joined by a slash (/); this happens to be the default implementation
      #    for ActiveRecord objects. If the object does not respond to **:id**, no fingerprint is generated.
      #  - **:created_at** The object's creation date, if the object responds to the +created_at+ method.
      #  - **:updated_at** The last time of modification for the object, if the object responds to
      #    the +updated_at+ method.
      #  - **:permissions** A dictionary whose keys are permission names (**:edit**, **:destroy**), and the values
      #    the permissions granted; see {Fl::Core::Access::Access} for details. A `false` or `nil`
      #    value indicates that the operation is not allowed.
      #    If *opts* contains the **:as_visible_to** key, its value will be used instead of *actor* for access control.

      def to_hash_base(actor, keys, opts = {})
        base = {}

        keys.each do |k|
          case k
          when :type
            base[:type] = self.class.name
          when :id
            base[:id] = self.id if self.respond_to?(:id)
          when :global_id
            base[:global_id] = self.to_global_id.to_s
          when :api_root
            base[:api_root] = self.to_hash_api_root()
          when :fingerprint
            if self.respond_to?(:fingerprint)
              base[:fingerprint] = self.fingerprint
            elsif self.respond_to?(:id)
              base[:fingerprint] = "#{self.class.name}/#{self.id}"
            end
          when :created_at
            base[:created_at] = to_hash_date(self.created_at) if self.respond_to?(:created_at)
          when :updated_at
            base[:updated_at] = to_hash_date(self.updated_at) if self.respond_to?(:updated_at)
          when :permissions
            base[:permissions] = if opts.has_key?(:as_visible_to)
                                   to_hash_permission_list(opts[:as_visible_to], opts[:permissions])
                                 else
                                   to_hash_permission_list(actor, opts[:permissions])
                                 end
          end
        end

        base
      end

      # Get the hash options for a given key.
      # This method looks up +key+ in the **:to_hash** value in +opts+, and returns its value if
      # present. Otherwise, it returns +defaults+ if provided. Finally, it returns an empty hash.
      #
      # Note that, since the return value is a reference to the +to_hash+ component for +key+,
      # you probably want to make a copy of it if you plan on changing it. Otherwise, your local
      # changes will be propagated at higher levels.
      #
      # @param key [Symbol] The key (which is an attribute name) to look up.
      # @param opts [Hash] A hash containing hash options.
      # @param defaults [Hash] Default options.
      #
      # @return [Hash] Returns a hash as described above.

      def to_hash_options_for_key(key, opts, defaults = nil)
        self.class.to_hash_options_for_key(key, opts, defaults)
      end
    end

    # Extract to_hash options from a hash.
    # A utility method that looks up **:to_hash** in +opts+, and returns its value; otherwise, returns {}.
    #
    # @param opts [Hash] The hash to examine.
    #
    # @return Returns a hash containing #to_hash options. If you plan on modifying the value, you might
    #  want to make a copy first, so that the original is not affected.

    def self.to_hash_options(opts)
      if opts && opts.has_key?(:to_hash)
        opts[:to_hash]
      else
        {}
      end
    end

    # Get the hash options for a given key.
    # This method looks up +key+ in the **:to_hash** value in +opts+, and returns its value if
    # present. Otherwise, it returns +defaults+ if provided. Finally, it returns an empty hash.
    #
    # Note that, since the return value is a reference to the +to_hash+ component for +key+,
    # you probably want to make a copy of it if you plan on changing it. Otherwise, your local
    # changes will be propagated at higher levels.
    #
    # @param key [Symbol] The key (which is an attribute name) to look up.
    # @param opts [Hash] A hash containing hash options.
    # @param defaults [Hash] Default options.
    #
    # @return [Hash] Returns a hash as described above.

    def self.to_hash_options_for_key(key, opts, defaults = nil)
      if opts && opts.has_key?(:to_hash) && opts[:to_hash].has_key?(key)
        opts[:to_hash][key]
      else
        (defaults.is_a?(Hash)) ? defaults : nil
      end
    end

    # @!endgroup

    # Callback for module loading: injects Fl::ModelHash::ClassMethods in the class methods,
    # and Fl::ModelHash::InstanceMethods in the instance methods.
    # It also defines wrappers to {Fl::Core::ModelHash#to_hash_options} and
    # {Fl::Core::ModelHash#to_hash_options_for_key} as class methods of the including class.

    def self.included(base)
      base.extend ClassMethods
      base.class_eval do
        include InstanceMethods

        # Extract to_hash options from a hash.
        # A utility method that looks up **:to_hash** in +opts+, and returns its value; otherwise, returns {}.
        #
        # @param opts The hash to examine.
        #
        # Returns a hash containing #to_hash options. If you plan on modifying the value, you might want to make
        # a copy first, so that the original is not affected.

        def self.to_hash_options(opts)
          Fl::Core::ModelHash.to_hash_options(opts)
        end

        # Get the hash options for a given key.
        # This method looks up +key+ in the **:to_hash** value in +opts+, and returns its value if
        # present. Otherwise, it returns +defaults+ if provided. Finally, it returns an empty hash.
        #
        # Note that, since the return value is a reference to the +to_hash+ component for +key+,
        # you probably want to make a copy of it if you plan on changing it. Otherwise, your local
        # changes will be propagated at higher levels.
        #
        # @param key The key (which is an attribute name) to look up.
        # @param opts A hash containing hash options.
        # @param defaults [Hash] Default options.
        #
        # @return Returns a hash as described above.

        def self.to_hash_options_for_key(key, opts, defaults = nil)
          Fl::Core::ModelHash.to_hash_options_for_key(key, opts, defaults)
        end
      end
    end
  end
end
