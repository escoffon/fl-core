module Fl::Core::Attachment
  # Configuration options for an attachment type.
  # This subclass of Hash stores configuration options for a single attachment type and Rails environment.
  # It is a Hash that defines {#method_missing} to convert dot notation into key dereferencing.

  class Configuration < Hash
    # Initializer.
    #
    # @param defaults [Hash] Initial configuration values.

    def initialize(defaults)
      defaults.each do |k, v|
        self[k] = v
      end
    end

    # Handler for missing methods.
    # If *key* ends with a `=`, this is a setter method and the value of *key* (minus the `=`) is used
    # to add an entry in the hash whose value is *args[0]*.
    # Otherwise, this is a getter method and the value of *key* in the hash is returned.
    #
    # @param key [String] The method name; this is converted to a key for lookup into the hash.
    # @param args Arguments to the method.
    #
    # @return Returns the value of *key* in the hash, if one is present.
    #
    # @raise Raises an exception if this is a getter and *key* is not in the hash.

    def method_missing(key, *args)
      text = key.to_s

      if text[-1,1] == "="
        self[text.chop.to_sym] = args[0]
      else
        raise "undefined attachment configuration option: #{key}" unless self.has_key?(key)
        self[key]
      end
    end
  end

  # Configuration manager dispatcher for attachments.
  # This is the main access point for configuration management; it is used to register configurations
  # for multiple attachment types and Rails environments.
  #
  # In general, an attachment type's configuration is assembled from three components:
  #
  # 1. Global configuration options, shared by all types and environments. These are registered (and
  #    accessed) via the {#defaults} method, using a `nil` type name.
  # 2. Type specific defaults; these are configuration options shared by all Rails environments for a
  #    given type. They are registered (and accessed) via the {#defaults} method, using a non-nil type name.
  # 3. Type and environment specific options. These are registered via the {#merge!} method.
  #
  # The typical setup process, then, takes place in three steps. First, there is the setting of global
  # configuration options:
  #
  # ```
  # Fl::Core::Attachment.config.defaults(nil, {
  #   hash_secret: "TheHashSecret",
  #   global_option: 'AGlobalOption'
  # })
  # ```
  # which are shared by all attachment types in all environments.
  # Then, each type defines configuration options that are common to all Rails environments:
  #
  # ```
  # Fl::Core::Attachment.config.defaults(:image, {
  #                                        styles: {
  #                                          large: { resize: "600x600>", strip: true' },
  #                                          medium: { resize: "200x200>", strip: true' },
  #                                          small: { resize: "100x100>", strip: true' },
  #                                          original: { }
  #                                        },
  #                                        default_style: :small
  #                                      })
  # ```
  # And, finally, environment-specific options:
  #
  # ```
  # Fl::Core::Attachment.config.merge!('production', :image, {
  #                                                    production_option: 'an option',
  #                                                    default_style: :medium
  #                                                  })
  # ```
  #
  # Note that you can override options with more specific ones.
  # The example sets up the default value for **default_style** to `:small`, and then overrides it for the
  # `production` Rails environment.
  #
  # You can clone configurations like this:
  #
  # ```
  # Fl::Core::Attachment.config.clone('production', :image, 'staging')
  # ```
  # And you can remove configuration options:
  #
  # ```
  # Fl::Core::Attachment.config.clear!('test', :image, [ :global_option ])
  # ```
  # This statement removes the **:global_option** key from the configuration options for the **:image**
  # attribute in the `test` Rails environment.
  # To remove an option from the defaults, you can use the `delete` method directly:
  #
  # ```
  # Fl::Core::Attachment.config.defaults(:image).delete(:option_name)
  # ```

  class ConfigurationDispatcher
    # Initializer.

    def initialize()
      @environments = {}
      @global_defaults = {}
      @defaults = {}
    end

    # Array/hash indexing operator.
    #
    # @param type [Symbol] The attachment type whose configuration to look up.
    #
    # @return [Configuration] The object holding the configuration for *type*; if no object exists yet,
    #  an empty one is created.

    def [](type)
      _access(::Rails.env, type.to_sym)
    end

    # Get or set the default configuration value for an attachment type.
    # Default configuration values are shared by all environments for a given type.
    #
    # @param type [Symbol] The attachment type; if `nil`, these are global defaults for all types.
    # @param opts [Hash, nil] The default configuration; if `nil`, no value is set and this method
    #  is essentially an accessor.
    #
    # @return The configuration defaults for *type* (or the global defaults, if *type* is `nil`).

    def defaults(type = nil, opts = nil)
      if type.nil?
        if opts.nil?
          @global_defaults
        else
          @global_defaults = opts
        end
      else
        stype = type.to_s
        if opts.nil?
          @defaults[stype] || {}
        else
          @defaults[stype] = opts
          @defaults[stype]
        end
      end
    end

    # Merge configuration options into the current configuration for a type and Rails environment.
    # This method merges the configuration in *opts* into the default configuration for *type*,
    # and saves the resulting configuration under the Rails environment *env*.
    #
    # @param env [String] The name of the Rails environment; if `nil`, use the current environment.
    # @param type [Symbol] The attachment type.
    # @param opts [Hash] Configuration to merge.

    def merge!(env, type, opts)
      env = ::Rails.env if env.nil?
      _access(env, type.to_sym).merge!(opts)
    end

    # Clear configuration options from the current configuration for a type and Rails environment.
    # This method removes keys in *keys* from the configuration for type *type* under the Rails
    # environment *env*.
    #
    # @param env [String, Symbol] The name of the Rails environment; if `nil`, use the current environment.
    #  If *env* is the symbol +:all+, the options are removed from all registered environments.
    # @param type [Symbol] The attachment type.
    # @param keys [Symbol, Array<Symbol>] The list of keys to remove; a single symbol is converted to a one
    #  element array.

    def clear!(env, type, keys)
      env = ::Rails.env if env.nil?
      stype = type.to_sym
      keys = [ keys ] unless keys.is_a?(Array)
      if env.is_a?(Symbol) && (env == :all)
        @environments.each do |ek, ev|
          if ev.has_key?(stype)
            cfg = ev[stype]
            keys.each { |k| cfg.delete(k.to_sym) }
          end
        end
      else
        cfg = _access(env, stype)
        keys.each { |k| cfg.delete(k.to_sym) }
      end
    end

    # Create a new configuration from an existing one.
    # A missing output type copies a configuration to a different Rails environment.
    #
    # @param env_in [String] The name of the Rails environment for the existing configuration.
    # @param type_in [Symbol] The attachment type for the existing configuration.
    # @param env_out [String] The name of the Rails environment for the new configuration.
    # @param type_out [Symbol] The attachment type for the new configuration; if `nil`, use the input type.

    def clone(env_in, type_in, env_out, type_out = nil)
      cfg_in = _access(env_in, type_in)
      env_out = env_if if env_out.nil?
      type_out = type_in if type_out.nil?
      _set(env_out, type_out, cfg_in)
    end

    # 
    # Check if a configuration exists for a given type.
    #
    # @param type [Symbol] The type to look up.
    #
    # @return [Boolean] Returns `true` if *type* has a configuration, `false` otherwise.

    def has_type?(type)
      (_access(::Rails.env, type.to_sym, true).nil?) ? false : true
    end

    # @overload config(type)
    #  Get a configuration for a given type in the current Rails environment.
    #  @param type [Symbol] The attachment type.
    #  @return Returns the configuration for *type*, if one is present; an initial value is created 
    #   if necessary.
    # @overload config(type, env)
    #  Get a configuration for a given type and Rails environment.
    #  @param type [Symbol] The attachment type.
    #  @param env [String] The name of the Rails environment to use.
    #  @return Returns the configuration for *type*, if one is present; an initial value is created 
    #   if necessary.

    def config(*args)
      stype = args[0].to_sym
      env = (args.count > 1) ? args[1].to_s : ::Rails.env
      _access(env, stype)
    end

    # @overload environment(env)
    #  Get the configuration entries for a given Rails environment.
    #  @param env [String] The name of the Rails environment to use.
    #  @return Returns the available configuration entries for *env*.
    # @overload environment()
    #  Get the configuration entries for the current Rails environment.
    #  @return Returns the available configuration entries for for the current Rails environment.

    def environment(*args)
      env = (args.count > 0) ? args[0].to_s : ::Rails.env
      @environments[env]
    end

    # Handler for missing methods.
    # If *type* ends with a `=`, this is a setter method and the value of *type* (minus the `=`) is used
    # to set the configuration options for the type with _args[0]_.
    # Otherwise, this is a getter method and the [Configuration] for *type* is returned; an initial value
    # is created if necessary; this is equivalent to calling the {#config} method with argument *type*.
    #
    # @param type [String] The method name; this is a type name for lookup into the attachment configurations.
    # @param args arguments to the method.
    #
    # @return Returns the configuration for *type*, if one is present.

    def method_missing(type, *args)
      text = type.to_s

      if text[-1,1] == "="
        _set(::Rails.env, text.chop.to_sym, args[0])
      else
        _access(::Rails.env, type)
      end
    end

    private

    def _access(env, stype, fail_if_missing = false)
      @environments[env] = {} unless @environments.has_key?(env)
      unless @environments[env].has_key?(stype)
        return nil if fail_if_missing
        @environments[env][stype] = Configuration.new(defaults().merge(defaults(stype)))
      end
      @environments[env][stype]
    end

    def _set(env, stype, cfg)
      @environments[env] = {} unless @environments.has_key?(env)
      @environments[env][stype] = Configuration.new(cfg)
    end
  end

  # @!visibility private
  @@dispatcher = nil

  # The global configuration dispatcher object.
  #
  # @return [ConfigurationDispatcher] Returns the global attachment configuration object.

  def self.config()
    @@dispatcher = ConfigurationDispatcher.new if @@dispatcher.nil?
    @@dispatcher
  end
end
