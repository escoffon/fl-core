require 'json'

module Fl::Core::Service
  # Base class for service object.
  # A service object implements the processing logic of application components; it typically
  # provides the glue between a controller and the underlying data layer.
  #
  # Service objects provide functionality to perform the following operations, so that the controller
  # code is streamlined and standardized.
  #
  # - Access control checks for the various operations. Access checking can be turned off
  #   by setting the configuration parameter **disable_access_check** to `true`.
  #   Also, if the service's {#model_class} does not respond to `has_permission?`, no access control
  #   is performed. See {Fl::Core::Access::Access::InstanceMethods#has_permission?}.
  # - CAPTCHA checks using a standardized workflow based on the `fl-google` gem.
  #   CAPTCHA checking can be turned off
  #   by setting the configuration parameter **disable_captcha** to `true`.
  # - The class includes {Fl::Core::Concerns::Service::Params} so that subclasses can use standard parameter
  #   management functionality.
  # - The class includes {Fl::Core::Concerns::Service::ApiResponse} so that subclasses can set standard
  #   {#status} values.
  #
  # {Fl::Core::Service::Base} is the base class that implements the common framework for request processing;
  # you subclass it to customize the behavior for a specific model class.
  # There is also a subclass {Fl::Core::Service::Nested} that provides the base class for service objects
  # used by nested resources.
  
  class Base
    include Fl::Core::Concerns::Service::Params
    include Fl::Core::Concerns::Service::ApiResponse
    
    # The key in the request parameters that contains the CAPTCHA response.
    CAPTCHA_KEY = 'captchaResponse'

    # The service actor.
    # @return [Object] Returns the *actor* parameter that was passed to the initializer.
    attr_reader :actor

    # The service parameters.
    # @return [ActionController::Parameters] Returns the parameters loaded into this object, as described
    #  in the documentation for the initializer.
    attr_reader :params

    # The service controller.
    # @return [ActionController::Base] Returns the *controller* parameter that was passed to the initializer.
    attr_reader :controller

    # Initializer.
    #
    # @param actor [Object] The actor (typically an object that mixed in {Fl::Core::Actor})
    #  on whose behalf the service operates. It may be `nil`.
    # @param params [Hash, ActionController::Parameters] The processing parameters. If the value is `nil`,
    #  the parameters are obtained from the `params` property of *controller*. If *controller* is also
    #  `nil`, the value is set to an empty hash. Hash values are converted to `ActionController::Parameters`.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options.
    # @option cfg [Boolean] :disable_access_checks Controls the access checks: set it to `true` to
    #  disable access checking. The default value is `false`.
    # @option cfg [Boolean] :disable_captcha Controls the CAPTCHA checks: set it to `true` to
    #  disable verification, even if the individual method options requested.
    #  This is mainly used during testing. The default value is `false`.
    #
    # @raise Raises an exception if the target model class has not been defined.

    def initialize(actor, params = nil, controller = nil, cfg = {})
      @actor = actor
      @controller = (controller.is_a?(ActionController::Base)) ? controller : nil
      p = if params.nil?
            (@controller.nil?) ? {} : @controller.params
          elsif params.is_a?(Hash)
            ActionController::Parameters.new(params)
          elsif params.is_a?(ActionController::Parameters)
            params
          else
            ActionController::Parameters.new({ })
          end
      @params = Fl::Core::Service::Base.adjust_params(p)
      
      raise "please define a target model class for #{self.class.name}" unless self.class.model_class

      @_has_instance_permission = self.model_class.instance_methods.include?(:has_permission?)
      @_has_class_permission = self.model_class.methods.include?(:has_permission?)

      @_disable_access_checks = (cfg[:disable_access_checks]) ? true : false
      @_disable_captcha = (cfg[:disable_captcha]) ? true : false

      @_to_hash_params = nil
      
      clear_status
    end

    # Parameters support/hack: adjust params.
    # This method traverses the hash stored in *p* and for each element it checks if the value is a hash
    # whose keys are all strings containing integers. If so, it assumes that the original parameters in the client
    # contained an array: it converts the hash back into an array of values and calls itself recursively on each.
    #
    # Otherwise, it calls itself recursively on the element's value.
    #
    # @param p [Hash, ActionController::Parameters] The parameters to adjust.
    #
    # @return [Hash, ActionController::Parameters] Returns an adjusted copy of *p*.

    def self.adjust_params(p)
      return p unless p.is_a?(ActionController::Parameters) || p.is_a?(Hash)

      # OK, first let's see if it looks like a "array hash"

      p_keys = p.keys
      numeric_keys = p_keys.reduce(0) do |acc, k|
        acc += 1 if k.to_s =~ /^[0-9]+$/
        acc
      end

      if numeric_keys != p_keys.count
        # looks like a normal hash: make sure that we adjust the values
        # unfortunately, since ActionController::Parameters does not support `reduce`, we have to use .each

        fv = if p.is_a?(ActionController::Parameters)
               ActionController::Parameters.new
             elsif p.is_a?(ActiveSupport::HashWithIndifferentAccess)
               ActiveSupport::HashWithIndifferentAccess.new
             elsif p.is_a?(Hash)
               { }
             end

        p.each do |pk, pv|
          fv[pk] = adjust_params(pv)
        end

        return fv
      else
        # This one gets converted
        # unfortunately, since ActionController::Parameters does not support `reduce`, we have to use .each

        rv = [ ]
        p.each do |pk, pv|
          rv[pk.to_i] = adjust_params(pv)
        end

        return rv
      end
    end
    
    # Hash support: returns a hash representation of an object, for the current user.
    #
    # @param actor [ApplicationRecord] The actor for which to hash the objects.
    # @param obj [Object] The object whose +to_hash+ method to call. The object should have included
    #  {Fl::Core::ModelHash}.
    # @param hash_opts [Hash] The hashing options for +to_hash+.
    #
    # @return [Hash] Returns a hash representation of _obj_; if *obj* does not respond to `to_hash`, returns an
    #  empty hash.

    def hash_one_object(actor, obj, hash_opts = { })
      # since obj could potentially be a hash, it defines its own to_hash method, which has different
      # arguments than the model hash one.
      # So, we need a bit of sleight of hand to decide which one to use, and we do it by the method's arity

      return { } unless obj.respond_to?(:to_hash)

      hma = obj.method(:to_hash).arity
      return obj.to_hash if hma == 0

      if (hma == -2) && (~hma == 1)
        # This has the expected arity for the model hash method
 
        return obj.to_hash(actor, hash_opts_for(actor, obj, hash_opts))
      else
        return { }
      end
    end

    # Hash support: returns an array of hash representations of objects, for the current user.
    #
    # @param actor [ApplicationRecord] The actor for which to hash the objects.
    # @param ary [Array<Object>] The array of objects whose +to_hash+ method to call. The objects should have
    #  included {Fl::Core::ModelHash}.
    # @param hash_opts [Hash] The hashing options for +to_hash+.
    #
    # @return [Array<Hash>] Returns an array of hash representations of _ary_.

    def hash_objects(actor, ary, hash_opts = { })
      ary.map { |r| hash_one_object(actor, r, hash_opts) }
    end

    protected

    # Adjust the hash options for an object.
    # This method adjusts hash options for *obj* before calling its `to_hash` methods.
    # It can be used by subclasses to make per object adjustments to the default hash options.
    #
    # The default implementattion returns *hash_opts*.
    #
    # @param actor [ApplicationRecord] The actor for which to hash the objects.
    # @param obj [Object] The object whose +to_hash+ method to call. The object should have included
    #  {Fl::Core::ModelHash}.
    # @param hash_opts [Hash] The hashing options for `to_hash`.
    #
    # @return [Hash] Returns the adjusted hash options.

    def hash_opts_for(actor, obj, hash_opts = { })
      return hash_opts
    end
    
    # @!attribute _disable_access_checks [r]
    # The access check flag.
    # This internal attribute is set to `true` if access checks are disabled; {#initialize} sets it
    # based on the value of the **:disable_access_checks** key in *cfg*.
    #
    # @return [Boolean] Return `true` if access checks are disabled, `false` otherwise.

    attr_reader :_disable_access_checks
    
    # @!attribute _disable_captcha [r]
    # The CAPTCHA check flag.
    # This internal attribute is set to `true` if CAPTCHA checks are disabled; {#initialize} sets it
    # based on the value of the **:disable_captcha** key in *cfg*.
    #
    # @return [Boolean] Return `true` if CAPTCHA checks are disabled, `false` otherwise.

    attr_reader :_disable_captcha

    public
    
    # @!attribute [r] localization_prefix
    # The localization prefix.
    # This string is prefixed to localization strings; it is obtained from the class name by replacing 
    # `::` with `.` and then calling `underscore` on the result.
    # So for example the localization prefix for class `My::Service::Asset::MyAsset` is
    # `my.service.asset.my_asset`. This value is prepended to the {I18n} lookup key for translations.
    #
    # @return [String] Returns the localization prefix as described above.

    def localization_prefix()
      unless @localization_prefix
        @localization_prefix = self.class.name.gsub('::', '.').underscore
      end
      @localization_prefix
    end

    # Build a localized message.
    # This method first tries to generate a localized message using the {#localization_key}; if this fails
    # (typically because the subclass has not defined a localization file), it tries the default localization
    # prefix `fl.core.service`.
    #
    # @param key [String,Symbol] This is the class-independent component of the translation key; the method
    #  tries `localization_key(key)` and <code>fl.core.service.<i>key</i></code>.
    # @param options [Hash] The rest of the call parameters contain a hash of key substitutions to pass to the
    #  {I18n.translate_x} method.
    #
    # @return [String] Returns the localized message.

    def localized_message(key, **options)
      h = options.dup
      h[:default] = [ "fl.core.service.#{key}".to_sym, key.to_s.humanize ]
      I18n.tx(localization_key(key), **h)
    end

    # @!attribute [r] model_class
    # The target model class.
    # Wraps a call to {.model_class}.
    #
    # @return [Class] Returns the model class.

    def model_class()
      self.class.model_class
    end

    # @!attribute [r] status
    # The status of the last call made.
    #
    # @return [Hash] Returns a hash containing the status of the last operation performed.
    #  The following keys may be present:
    #
    #  - **:status** A symbol describing the primary status of the call; see the constants defined
    #    in {Fl::Core::Service}. A value other than {Fl::Core::Service::OK} implies that the call failed.
    #  - **:response_data** is a hash containing response details. Typically, this hash contains a single
    #    key with the same name as **:status**; for example, if **:status** is
    #    {Fl::Core::Service::FORBIDDEN}, the key **:forbidden** is present. Under some circumstances, the
    #    response data from multiple status vales may be present, but this is a rare occurrence.
    #
    # The values of keys in **:response_data** should be consistent with those returned by
    # {Fl::Core::Concerns::Service::ApiResponse#error_response_data} or
    # {Fl::Core::Concerns::Service::ApiResponse#success_response_data}.
    # For example, a successful response status may look like this:
    #
    # ```
    # {
    #   status: :ok,
    #   response_data: {
    #     ok: {
    #       _status: { message: 'The operation was successful' }
    #     }
    #   }
    # }
    # ```
    #
    # and an error:
    #
    # ```
    # {
    #   status: :unprocessable_entity,
    #   response_data: {
    #     unprocessable_entity: {
    #       _error: {
    #         type: 'missing_parameter',
    #         message: 'missing parameter :my_parameter'
    #       }
    #     }
    #   }
    # }
    # ```
    #
    # Note that {Fl::Core::Concerns::Service::ApiResponse#error_response_data} and
    # {Fl::Core::Concerns::Service::ApiResponse#success_response_data} are available as instance methods.

    def status()
      @status.dup
    end

    # Get the a response data hash.
    # This method returns the response data corresponding to *status*.
    #
    # @param s [Symbol] The status value (for example, {Fl::Core::Service::FORBIDDEN}).
    #  If `nil`, use the current status value.
    #
    # @return [Hash,nil] Returns the response data, `nil` if not found.

    def status_response_data(s = nil)
      s = self.status[:status] if s.nil?
      @status[:response_data][s.to_sym]
    end
    
    # Clear the status.
    # The method sets the service in the success status.

    def clear_status()
      @status = { status: Fl::Core::Service::OK, response_data: { } }
      @status[:response_data][Fl::Core::Service::OK] = { }
    end

    # Set the status.
    # Note that *response_data* is added to the {#status} under a key corresponding to the value of *status*;
    # for example, a call to
    #
    # ```
    # self.set_status(Fl::Core::Service::FORBIDDEN, {
    #   type: 'custom_failure',
    #   message: 'custom failure message',
    #   details: { more: 'more details here' }
    # })
    # ```
    #
    # generates this value of {#status}:
    #
    # ```
    # {
    #   status: :forbidden,
    #   response_data: {
    #     forbidden: { 
    #       type: 'custom_failure',
    #       message: 'custom failure message',
    #       details: { more: 'more details here' }
    #     }
    #   }
    # }
    # ```
    #
    # {Fl::Core::Concerns::Service::ApiResponse#error_response_data} is often used to simplify status data
    # generation.
    #
    # @param status [Symbol] The status value (for example, {Fl::Core::Service::FORBIDDEN}).
    # @param response_data [Hash] The response data; this value is added to the {#status} response data under the
    #  key corresponding to *status*.
    # @param clear [Boolean] Clear any other entries in the response data. If `false`, *response_data* is
    #  added to {#status}'s **:response_data** key under *status*; if `true`, all other keys in **:response_data**
    #  are removed. The default is `true`, so that typically only one response is present, but under some
    #  cirsumstances you may want to save multiple responses from a single operation.

    def set_status(status, response_data = nil, clear = true)
      @status = {} unless @status.is_a?(Hash)
      @status[:status] = status
      @status[:response_data] = { } unless @status[:response_data].is_a?(Hash)
      if clear
        @status[:response_data] = { "#{status}".to_sym => response_data }
      else
        @status[:response_data][status.to_sym] = response_data
      end
    end

    # @!attribute [r] success?
    # Checks if the status indicates success.
    #
    # @return [Boolean, nil] Returns `true` if the current status contains a {Fl::Core::Service::OK} value in the
    #  +:status+ key, `false` otherwise. If there is no +:status+ key, returns `nil`.

    def success?()
      return nil unless @status && @status.has_key?(:status)
      @status[:status] == Fl::Core::Service::OK
    end

    # Check if the actor has permission to execute an action.
    # This method first normalizes *action*: if `nil`, if #{controller} responds to **:action_name**, use that value,
    # and otherwise use {#params}[:action]; if a string, leave it as is;
    # if a symbol, convert to a string; and otherwise, return `false`.
    # Then, it clears the status, and calls {#do_access_checks?}, passing it the normalized *action*, *obj*,
    # and *opts*; if the return
    # value is `false`, access checks are not enabled for this operation, and therefore it returns `true`.
    # Otherwise, it calls {#_has_action_permission?}, which implements the actual access check process.
    # If the return value is `true`, it returns `true` to indicate that the action is
    # allowed. If it is `false`, it checks if {#_has_action_permission?} has set the error state, and if not
    # it sets it with a default value.
    # Finally, it returns `false`.
    #
    # @param action [String,Symbol,nil] The action for which to check for permission.
    #  If `nil`, use the value of **:action** from the {#params} attribute.
    # @param obj [Object,Class] The object to use to check the permission.
    #  For collection-level actions like `index` and `create`, this is typically {#model_class};
    #  for member-level actions like `update`, it is typically an instance of {#model_class}.
    # @param opts [Hash] A hash of options to pass to the access check methods.
    #
    # @return [Boolean] Returns `false` if the permission is not granted.

    def has_action_permission?(action = nil, obj = nil, opts = nil)
      a = normalize_action(action)
      return false if a.nil?

      self.clear_status
      return true if !do_access_checks?(a, obj, opts)
      return true if _has_action_permission?(a, obj, opts)

      if self.success?
        # since _has_action_permission? has not changed the status, create a standard one here

        id = if obj.is_a?(Class)
               obj.name
             elsif obj.respond_to?(:fingerprint)
               obj.fingerprint
             elsif obj.is_a?(Integer) || (obj.is_a?(String) && (obj =~ /^[0-9]$/))
               self.model_class.fingerprint(obj)
             elsif obj.nil?
               self.model_class.fingerprint(params[:id])
             else
               obj.to_s
             end
        self.set_status(Fl::Core::Service::FORBIDDEN,
                        error_response_data('no_permission',
                                            localized_message('forbidden', id: id, action: action)))
      end

      return false
    end

    protected
    
    # Perform the permission check for an action.
    # This method defines the access check algorithms for the standard Rails actions:
    #
    # 1. If *obj* does not respond to `has_permission?`, return `false`.
    # 2. Set the requested permission based on the value of *action*, as described below.
    # 3. Calls {Fl::Core::Access::Access::ClassMethods#has_permission?} on *obj* using the requested permission.
    #
    # The first step makes the permission checker very restrictive, since refuses to grant permission if *obj*
    # does not support the standard access control protocol. Subclasses that manage objects that do not respond
    # `has_permission?`, but that still want to implement some access control, will have to override this method
    # to implement their specialized access control.
    #
    # The following action names are supported:
    #
    # - **index** with permission {Fl::Core::Access::Permission::Index}.
    # - **create** with permission {Fl::Core::Access::Permission::Create}.
    # - **show** with permission {Fl::Core::Access::Permission::Read}.
    # - **update** with permission {Fl::Core::Access::Permission::Write}.
    # - **destroy** with permission {Fl::Core::Access::Permission::Delete}.
    # 
    # Subclasses will have to override this implementation for two reasons.
    # The first is to implement access checks for a nonstandard action. For example, for a service that
    # implements the `search` action:
    #
    # ```
    # class MyService < Fl::Core::Servcie::Base
    #   def _has_action_permission?(action, obj, opts = nil)
    #     if action == 'search'
    #       run_search_access_checks(action, obj, opts)
    #     else
    #       super(action, obj, opts)
    #     end
    #   end
    # end
    # ```
    #
    # The second reason is to use a different access control mechanism for a standard action:
    #
    # ```
    # class MyService < Fl::Core::Servcie::Base
    #   def _has_action_permission?(action, obj, opts = nil)
    #     if action == 'index'
    #       run_my_index_access_checks(action, obj, opts)
    #     else
    #       super(action, obj, opts)
    #     end
    #   end
    # end
    # ```
    #
    # The base implementation does not set the status, so that a default (and somewhat uninformative) error is
    # reported. Subclasses can set specialized status error values (see {#set_status}), which will be used
    # by {#has_action_permission?}. However, the *status* parameter for {#set_status} should be set to {FORBIDDEN}.
    #
    # @param action [String] The action for which to check for permission; the value has been normalized to a
    #  string by {#has_action_permission?}.
    # @param obj [Object,Class] The object to use to check the permission.
    #  For collection-level actions like `index` and `create`, this is typically {#model_class};
    #  for member-level actions like `update`, it is typically an instance of {#model_class}.
    # @param opts [Hash] A hash of options to pass to the access check methods.
    #
    # @return [Boolean] Returns `false` if the permission is not granted.

    def _has_action_permission?(action, obj, opts = nil)
      return false unless obj.respond_to?(:has_permission?)
      
      p = case action
          when 'index'
            Fl::Core::Access::Permission::Index::NAME
          when 'create'
            Fl::Core::Access::Permission::Create::NAME
          when 'show'
            Fl::Core::Access::Permission::Read::NAME
          when 'update'
            Fl::Core::Access::Permission::Write::NAME
          when 'destroy'
            Fl::Core::Access::Permission::Delete::NAME
          else
            nil
          end

      (p.nil?) ? false : obj.has_permission?(p, self.actor, opts)
    end

    public

    # Look up an object in the database, and check if the service's actor has permissions on it.
    # This method uses the **:id** entry in *params* to look up the object in the database
    # (using the target model class as the context for `find`).
    # If it does not find the object, it sets the status to {Fl::Core::Service::NOT_FOUND} and
    # returns `nil`.
    # If it finds the object, it then calls {Fl::Core::Access::Access::InstanceMethods#has_permission?}
    # to confirm that the actor has *permission* access to the object.
    # If the permission call fails, it sets the status to {Fl::Core::Service::FORBIDDEN} and returns `nil`.
    # Otherwise, it sets the status to {Fl::Core::Service::OK} and returns the object.
    #
    # @param action [String,Symbol,nil] The action for which to check for permission.
    #  If `nil`, no access check is performed and the call is the equivalent of a simple database lookup.
    # @param idname [Symbol, Array<Symbol>] The name or names of the key in *params* that contain the object
    #  identifier; array elements are tried until a hit.
    #  A `nil` value defaults to **:id**.
    # @param pars [Hash] The parameters where to look up the **:id** key used to fetch the object.
    #  If `nil`, use the value of {#params}.
    # @option context [Object] The context to pass to the access check method {#has_action_permission?}.
    #  The special value `:params` (a Symbol named `params`) indicates that the value of *params* is to be
    #  passed as the context.
    #  Defaults to `nil`.
    #
    # @return [Object, nil] Returns an object, or `nil`.
    #  Note that the object is returned only if all the checks succeed; in particular, if permission for the
    #  operation is not granted, no object is returned even if one was found in the database.

    def get_and_check(action, idname = nil, pars = nil, opts = nil)
      idname = idname || :id
      pars = normalize_params(pars || self.params)
      opts = pars if (opts == :params)

      obj, kvp = find_object(self.model_class, idname, pars)
      if obj.nil?
        self.set_status(Fl::Core::Service::NOT_FOUND,
                        error_response_data('not_found',
                                            localized_message('not_found', id: flatten_param_keys(kvp).join(','))))
      else
        if !action.nil?
          if has_action_permission?(action, obj, opts)
            self.clear_status
          else
            obj = nil
          end
        end
      end
      
      obj
    end

    # Run a CAPTCHA verification.
    # CAPTCHA verification is performed as follows:
    #
    # 1. If the ckecks are disabled, return a success value.
    # 2. Look up the key **captchaResponse** in {#create_params}, and if not found
    #    sets the status to {Fl::Core::Service::UNPROCESSABLE_ENTITY} and return a failure value.
    # 3. Creates an instance of the CAPTCHA verifier using {Fl::Core::CAPTCHA.factory} and calls
    #    its `verify` method.
    #    On error, sets the status to {Fl::Core::Service::UNPROCESSABLE_ENTITY}.
    # 4. Return the response from the verification method.
    #
    # Note that verification failures have the side effect of setting the status, so that clients can use
    # {#success?} or check the **success** field in the return value to determine if the call was successful.
    #
    # @param [Boolean,Hash] opts The CAPTCHA options. If `nil` or `false`, return a success value: no
    #  verification is requested. If a hash or `true`, run the verification; the hash value is passed
    #  to {Fl::Core::CAPTCHA.factory}.
    #
    # @return [Hash] Returns a hash with the same structure as the return value from
    #  {Fl::Google::RECAPTCHA#verify}.

    def verify_captcha(opts, params)
      return { 'success' => true } unless do_captcha_checks?

      if opts
        captcha = params.delete(CAPTCHA_KEY)
        if captcha.is_a?(String) && (captcha.length > 0)
          rq = Fl::Core::CAPTCHA.factory((opts.is_a?(Hash)) ? opts : {})
          rv = rq.verify(captcha, remote_ip)
          unless rv['success']
            self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                            error_response_data('captcha.verification-failure',
                                                localized_message('captcha.verification-failure',
                                                                  messages: rv['error-messages'].join(', '))))
          end
          rv
        else
          self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                          error_response_data('captcha.no-captcha',
                                              localized_message('captcha.no-captcha', key: CAPTCHA_KEY)))
          { 'success' => false, 'error-codes' => [ 'no-captcha' ] }
        end
      else
        { 'success' => true }
      end
    end

    # Create an instance of the model class.
    # This method attempts to create and save an instance of the model class; if either operation fails,
    # it sets the status to {Fl::Core::Service::UNPROCESSABLE_ENTITY} and loads a message and the
    # **:details** key in the error status from the object's **errors**. 
    #
    # The method calls {#has_action_permission?} with action `create` to confirm that the
    # service's *actor* has permission to create objects. If the permission is not granted, `nil` is returned.
    # It then calls {#new_object} to build an unpersisted instance of the object.
    # If {#new_object} returns a non-nil instance, the method first saves the object to persist it into the
    # database, and if that succeeds it calls {#after_create} to give subclasses a hook
    # to perform additional processing. If {#after_create} returns a failure result, the object is destroyed
    # before returning an error status. We do this bit of song and dance to support situations where the creation
    # of an object may trigger creation of related but not dependent objects.
    #
    # Note that {#new_object} and {#after_create} should call {#set_status} to set appropriate failure results;
    # this method generates a standard failure result if either call fails and the current status is still
    # reporting success.
    #
    # @param opts [Hash] Options to the method. This section describes the common options; subclasses may
    #  define type-specific ones.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to {#create_params}
    #  to generate the hash to pass to the object initializer. If not present or `nil`, use {#params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate CAPTCHA object
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to the initializer for the CAPTCHA object.
    # @option opts [Object] :context The context to pass to the access check method {#has_action_permission?}.
    #  The special value **:params** (a Symbol named `params`) indicates that the create parameters are to be
    #  passed as the context.
    #  Defaults to **:params**.
    #
    # @return [Object, nil] Returns an instance of the {#model_class}. Note that a non-nil return value
    #  does not indicate that the call was successful; for that, you should call {#success?} or check if
    #  the instance is valid.

    def create(opts = {})
      p = create_params((opts[:params]) ? opts[:params] : self.params).to_h
      ctx = if opts.has_key?(:context)
              (opts[:context] == :params) ? p : opts[:context]
            else
              # This is equivalent to setting the default to :params

              p
            end

      begin
        obj = nil
        if has_action_permission?('create', self.model_class, ctx)
          rs = verify_captcha(opts[:captcha], p)
          if rs['success']
            self.clear_status
            
            obj = new_object(p)
            if !obj.nil? && obj.save
              if !after_create(obj, p)
                obj.destroy
                obj = nil

                # We set the status if it is still marked as being successful; if not, then after_create
                # has already set it and we don't override it
                  
                if self.success?
                  self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                                  error_response_data('creation_failure',
                                                      localized_message('creation_failure', class: self.model_class.name),
                                                      nil))
                end
              end
            else
              # We set the status if it is still marked as being successful; if not, then one of the calls above
              # has already set it and we don't override it
                  
              if self.success?
                self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                                error_response_data('creation_failure',
                                                    localized_message('creation_failure', class: self.model_class.name),
                                                    (obj) ? obj.errors : nil))
              end
            end
          end
        end

        return obj
      rescue Exception => exc
        self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                        exception_response_data('creation_failure',
                                                localized_message('creation_failure', class: self.model_class.name),
                                                exc))
        return nil
      end
    end
    
    # Update an instance of the model class.
    # This method attempts to update an instance of the model class; if the operation fails,
    # it sets the status to {Fl::Core::Service::UNPROCESSBLE_ENTITY} and loads a message and the
    # **:details** key in the error status from the object's `errors`. 
    #
    # The method calls {#has_action_permission?} with action `update` to confirm that the
    # service's {#actor} has permission to update the object.
    # If the permission is not granted, `nil` is returned.
    # Orherwise, it calls {#update_object} and {#after_update}, and if either returns `false` if fails the
    # operation.
    #
    # @param opts [Hash] Options to the method. This section describes the common options; subclasses may
    #  define type-specific ones.
    # @option opts [Symbol,String] :idname The name of the key in **:params** that contains the object
    #  identifier.
    #  Defaults to **:id**.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to {#update_params}
    #  to generate the hash to pass to the object initializer. If not present or `nil`, use {#params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate CAPTCHA object
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to {Fl::Core::CAPTCHA.factory}.
    # @option opts [Object] :context The context to pass to the access check method {#has_action_permission?}.
    #  The special value `:params` (a Symbol named `params`) indicates that the create parameters are to be
    #  passed as the context.
    #  Defaults to `:params`.
    #
    # @return [Object, nil] Returns the updated object. Note that a non-nil return value
    #  does not indicate that the call was successful; for that, you should call {#success?} or check if
    #  the instance is valid.

    def update(opts = {})
      p = update_params((opts[:params]) ? opts[:params] : self.params).to_h
      ctx = if opts.has_key?(:context)
              (opts[:context] == :params) ? p : opts[:context]
            else
              # This is equivalent to setting the default to :params

              p
            end
      idname = (opts[:idname]) ? opts[:idname].to_sym : :id

      obj = get_and_check('update', idname, self.params, ctx)
      if obj && success?
        begin
          rs = verify_captcha(opts[:captcha], p)
          if rs['success']
            unless update_object(obj, p) && after_update(obj, p)
              if self.success?
                self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                                error_response_data('update_failure',
                                                    localized_message('update_failure', fingerprint: obj.fingerprint),
                                                    obj.errors))
              end
            end
          end
        rescue Exception => exc
          self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                          exception_response_data('update_failure',
                                                  localized_message('update_failure', fingerprint: obj.fingerprint),
                                                  exc))
        end
      end

      return obj
    end
    
    # Destroy an instance of the model class.
    # This method attempts to destroy an instance of the model class; if the operation fails,
    # it sets the status to {Fl::Core::Service::UNPROCESSBLE_ENTITY} and loads a message and the
    # **:details** key in the error status from the object's `errors`. 
    #
    # The method calls {#has_action_permission?} with action `destroy` to confirm that the
    # service's {#actor} has permission to destroy the object.
    # If the permission is not granted, `false` is returned.
    #
    # @param opts [Hash] Options to the method. This section describes the common options; subclasses may
    #  define type-specific ones.
    # @option opts [Symbol,String] :idname The name of the key in **:params** that contains the object
    #  identifier.
    #  Defaults to **:id**.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to the object's
    #  initializer. If not present or `nil`, use the value returned by {#params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate CAPTCHA object
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to {Fl::Core::CAPTCHA.factory}.
    # @option opts [Object] :context The context to pass to the access check method {#has_action_permission?}.
    #  The special value `:params` (a Symbol named `params`) indicates that the create parameters are to be
    #  passed as the context.
    #  Defaults to `:params`.
    #
    # @return [Array] Returns an array containing two elements. The first is a boolean value `true` if the object
    #  was destroyed, `false` otherwise; in the latter case, {#status} contains additional information.
    #  The second element is the object that was destroyed.

    def destroy(opts = {})
      p = (opts[:params]) ? opts[:params].to_h : self.params
      ctx = if opts.has_key?(:context)
              (opts[:context] == :params) ? p : opts[:context]
            else
              # This is equivalent to setting the default to :params

              p
            end
      idname = (opts[:idname]) ? opts[:idname].to_sym : :id

      obj = get_and_check('destroy', idname, self.params, ctx)
      if obj && success?
        begin
          rs = verify_captcha(opts[:captcha], p)
          if rs['success']
            return [ true, obj ] if obj.destroy && obj.destroyed?

            self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                            error_response_data('destroy_failure',
                                                localized_message('destroy_failure', fingerprint: obj.fingerprint),
                                                obj.errors))
          end
        rescue Exception => exc
          self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                          exception_response_data('update_failure',
                                                  localized_message('update_failure', fingerprint: obj.fingerprint),
                                                  exc))
        end
      end

      return [ false, obj ]
    end

    # Convert parameters to `ActionController::Parameters`.
    # This method calls {.strong_params}; if *p* is `nil`, it uses the value of {#params}, otherwise it
    # uses *p*.
    #
    # @param p [Hash,ActionController::Parameters,String,nil] The parameters to convert.
    #  If a string value, it is assumed to contain a JSON representation.
    #  If `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the converted parameters.

    def strong_params(p = nil)
      self.class.strong_params((p.nil?) ? self.params : p)
    end

    # Get query parameters.
    # This method is meant to be overridden by subclasses to implement class-specific lookup of creation
    # parameters. A typical implementation uses the Rails strong parameters functionality, as in the
    # example below.
    #
    # ```
    #   def query_params(p = nil)
    #     return normalize_query_params(p).permit({ p1: [ ] }, :p2)
    #   end
    # ```
    #
    # @param p [Hash,ActionController::Params,String] The parameter value.
    #
    # @return [ActionController::Parameters] Returns the query parameters.

    def query_params(p = nil)
      raise "please implement #{self.class.name}#query_params"
    end

    # Get create parameters.
    # This method is meant to be overridden by subclasses to implement class-specific lookup of creation
    # parameters. A typical implementation uses the Rails strong parameters functionality, as in the
    # example below.
    #
    # ```
    #   def create_params(p = nil)
    #     p = (p.nil?) ? params : strong_params(p)
    #     p.require(:my_context).permit(:param1, { param2: [] })
    #   end
    # ```
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset. If `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the create parameters.
    #
    # @raise The base implementation raises an exception to force subclasses to override it.

    def create_params(p = nil)
      raise "please implement #{self.class.name}#create_params"
    end

    # Get update parameters.
    # This method is meant to be overridden by subclasses to implement class-specific lookup of update
    # parameters. A typical implementation uses the Rails strong parameters functionality, as in the
    # example below.
    #
    # ```
    #   def update_params(p = nil)
    #     p = (p.nil?) ? params : strong_params(p)
    #     p.require(:my_context).permit(:param1, { param2: [] })
    #   end
    # ```
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the update parameters
    #  subset. If `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.
    #
    # @raise The base implementation raises an exception to force subclasses to override it.

    def update_params(p = nil)
      raise "please implement #{self.class.name}#update_params"
    end

    # Get `to_hash` parameters.
    # This method returns the permitted contents of the **to_hash** parameter.
    # It permits the following options (which are the standard options described in
    # {Fl::Core::Core::ModelHash::InstanceMethods#to_hash}):
    #
    # - The scalars *:as_visible_to*, *:verbosity*.
    # - The arrays *:only*, *:include*, *:except*, *:image_sizes*. All elements of these arrays are
    #   permitted; if you want to tailor those contents, override the method in the subclass.
    # - The hash *:to_hash*. All elements of this hash are permitted; if you want to tailor those
    #   contents, override the method in the subclass.
    #
    # Note that, although the {Fl::Core::Core::ModelHash::InstanceMethods#to_hash} method accepts
    # scalars as values for the *:only*, *:include*, and *:except* arrays, clients should also pass
    # the parameters as arrays, or they will be filtered out by the permission system.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the `to_hash`
    #  parameters subset.
    #
    # @return [ActionController::Parameters] Returns the standard permitted `to_hash` parameters.

    def self.to_hash_params(p)
      strong_params(strong_params(p).fetch(:to_hash, { })).permit(:as_visible_to, :verbosity,
                                                                  { only: [ ] }, { include: [ ] },
                                                                  { except: [ ] }, { image_sizes: [ ] },
                                                                  { to_hash: { } })
    end

    # Get `to_hash` parameters.
    # This method calls {.to_hash_params}, passing *p* if non-nil, or the value of {#params} if `nil`.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the `to_hash`
    #  parameters subset. If `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the standard permitted `to_hash` parameters.

    def to_hash_params(p = nil)
      if @_to_hash_params.nil?
        @_to_hash_params = self.class.to_hash_params((p.nil?) ? self.params : p)
      end

      return @_to_hash_params
    end

    protected

    # Factory for new objects.
    # This method is used by {#create} to give subclasses the ability to override the class of a created
    # object; this is typically used when a service object manages Single Table Inheritance hierarchies.
    #
    # The default implementation returns `self.model_class.new(p)`, which for most service object implementations
    # is the desired behavior.
    #
    # @param p [Hash] The hash to pass to the initializer.
    #
    # @return [ActiveRecord::Base] Returns a new object, which has not yet been persisted.

    def new_object(p)
      return self.model_class.new(p)
    end

    # Update wrapper for existing objects.
    # This method is used by {#update} to give subclasses the ability to override the update process.
    #
    # The default implementation calls `obj.update(p)`, which for most service object implementations
    # is the desired behavior.
    #
    # @param obj [ActiveRecord::Base] The object to update.
    # @param p [Hash] The hash to pass to the initializer.
    #
    # @return [Boolean] Returns `true` on a successful update, `false` otherwise.

    def update_object(obj, p)
      return obj.update(p)
    end
    
    # The backstop values for the query options.

    QUERY_BACKSTOPS = {
      :offset => 0,
      :limit => 20,
      :order => 'updated_at DESC'
    }

    # @!visibility private
    QUERY_INT_PARAMS = [ :offset, :limit ]

    # @!visibility private
    QUERY_DATETIME_PARAMS = [ :updated_since, :created_since, :updated_before, :created_before ]

    public

    # Runs a query based on the request parameters.
    #
    # 1. Call {#has_action_permission?} for the `index` action; if the return value is `false`, return `nil`.
    # 2. Call {#init_query_opts} to set up the query parameters.
    # 3. Call {#index_query} to set up the query.
    # 4. Call {#index_results} to get the result set.
    # 5. Generate a response payload containing the results and the pagination controls.
    # 6. Call {#adjust_index_results} to 
    #
    # The method catches any exceptions and sets the error state of the service from the
    # exception properties.
    #
    # @param query_opts [Hash] Query options to merge with the contents of <i>_q</i> and <i>_pg</i>.
    #  This is used to define service-specific defaults.
    # @param _q [Hash, ActionController::Parameters] The query parameters; if `nil`, extract them from `params`.
    # @param _pg [Hash, ActionController::Parameters] The pagination parameters; if `nil`, extract them from `params`.
    #
    # @return [Hash, nil] If a query is generated, it returns a Hash containing at least the following keys
    #  ({#adjust_index_results} may add other keys):
    #
    #  - *:result* are the results from the query; this is an array of objects.
    #  - *:_pg* are the pagination controls returned by {#pagination_controls}.
    #
    #  If no query is generated (in other words, if {#index_query} fails), it returns `nil`.
    #  It also returns `nil` if an exception was raised.

    def index(query_opts = {}, _q = nil, _pg = nil)
      begin
        return nil if !has_action_permission?('index', self.model_class)

        _q = query_params() if _q.nil?
        _pg = pagination_params if _pg.nil?

        qo = init_query_opts(query_opts, _q, _pg)
        q = index_query(qo)
        if q
          r = index_results(q)
          return adjust_index_results({
            result: r,
            _pg: pagination_controls(r, qo, self.params)
          })
        end
      rescue Exception => exc
        self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                        exception_response_data('query_error',
                                                localized_message('query_error', class: self.model_class.name),
                                                exc))
        return nil
      end
    end

    # Initialize the query options for the **:index** action.
    # This methods merges the contents of the *:_q* and *:_pg* keys in the submission parameters into the
    # default backstops.
    # It also converts some values to a canonical form (for example, integer-valued options are converted
    # to integer values).
    #
    # The value of the *:_q* key is a hash of options for the `:index` action. The value of the *:_pg* key is
    # a hash containing pagination control values:
    # - *:_s* is the page size (the number of items to return); a negative value means to return all items.
    # - *:_p* is the 1-based index of the page to return; the first page is at index 1.
    #
    # The method builds the query options as follows:
    #
    # 1. Set up default values for the query options from *defs* and {QUERY_BACKSTOPS}.
    # 2. The values in *_pg* (if any) are used to initialize the values for **:offset** and **:limit** in
    #    the query options: **:limit** is the value of the **:_s** key, and **:offset** is
    #    `(_pg[_p] - 1) * :limit`.
    # 3. Merge the values in *\_q* into the query options; **:offset** and **:limit** override the values
    #    from the previous step. Additionally, if **:limit** is negative, then *\_pg* is ignored;
    #    for example, if **:_s** is 4, **:_p** is 2, **:limit** is -1, and **:offset** is 4, then the new value
    #    of *\_pg* is `{ _s: -1, _p: 1 }`. See {#pagination_controls}.
    # 4. If the value of **:limit** is negative, **:limit** is removed from the query options.
    #
    # @param defs [Hash] A hash of default values for the options, which override the following backstops:
    #
    #  - **:offset** is 0.
    #  - **:limit** is 20. If the value in *defs* is -1, **:limit** is not placed in the query options.
    #  - **:order** is <tt>updated_at DESC</tt>.
    #  Any other keys in *defs* provide the backstop, and the method looks up an overriding
    #  value in <i>_q</i> and <i>_pg</i>.
    # @param _q [Hash] The query parameters, from the **:_q** key in the submission parameters.
    # @param _pg [Hash] The pagination parameters, from the **:_pg** key in the submission parameters.
    #
    # @return [ActiveSupport::HashWithIndifferentAcces] Returns a hash of query options.

    def init_query_opts(defs = {}, _q = {}, _pg = {})
      sdefs = {}
      if defs.is_a?(Hash)
        defs.each { |k, v| sdefs[k.to_sym] = v }
      end
      opts = QUERY_BACKSTOPS.merge(sdefs)

      opts[:limit] = _pg[:_s].to_i if _pg.has_key?(:_s)
      opts[:offset] = ((_pg[:_p].to_i - 1) * opts[:limit]) if _pg.has_key?(:_p)
      opts[:offset] = 0 if opts[:offset] < 0

      _q.each do |k, v|
        sk = k.to_sym
        if QUERY_INT_PARAMS.include?(sk)
          opts[sk] = v.to_i
        elsif QUERY_DATETIME_PARAMS.include?(sk)
          opts[sk] = ((v =~ /^[0-9]+$/).nil?) ? v : v.to_i
        else
          opts[sk] = v
        end
      end

      if _q.has_key?(:order)
        case _q[:order]
        when Array
          opts[:order] = _q[:order].join(', ')
        else
          opts[:order] = _q[:order]
        end
      end

      opts.delete(:limit) if opts[:limit] < 0

      return opts.with_indifferent_access
    end

    # Generate pagination control data for the next page in an `:index` query.
    # This methods generates a pagination control hash from the values of the options to an `:index` query.
    #
    # The method builds the pagination controls as follows:
    #
    # 1. Initialize with the values from **:_pg** in *pars*, if any.
    # 2. Set the value of **:_c** to the length of the *results* array, or to 0 if *results* is `nil`.
    # 3. If *opts* does not have a **:limit** value, set **:_s** to -1 and **:_p** to 1, since we cannot determine
    #    the page size and therefore calculate a starting page from the **:offset** option.
    # 4. Otherwise, set **:_s** to the value of **:limit** in *opts*, and **:_p** to the next page, based on the
    #    value of **:offset** and *:limit**.
    #
    # Note that setting **:offset** or **:limit** (or both) in *opts* may cause the pagination controls to be
    # inaccurate. Clients that use these two options should not rely on the pagination controls.
    #
    # @param results [Array, nil] An array containing the results from the query.
    # @param opts [Hash] A hash containing query options.
    # @param pars [Hash] The submission query parameters. If `nil`, the value of {#params} is used.
    #
    # @return [Hash] Returns a hash containing the pagination controls: **:_s** is the page size, **:_p** is the
    #  next page to fetch.

    def pagination_controls(results = nil, opts = {}, pars = nil)
      xp = (pars.is_a?(Hash)) ? pars : params
      _pg = (xp[:_pg].is_a?(Hash)) ? normalize_params(xp[:_pg]) : {}

      npg = {}
      npg[:_c] = (results.is_a?(Array)) ? results.count : 0
      npg[:_s] = _pg[:_s].to_i if _pg.has_key?(:_s)
      npg[:_p] = _pg[:_p].to_i if _pg.has_key?(:_p)

      if opts.has_key?(:limit) && (opts[:limit].to_i > 0)
        npg[:_s] = opts[:limit].to_i
        if opts.has_key?(:offset)
          npg[:_p] = ((opts[:offset].to_i + npg[:_s]) / npg[:_s]) + 1
          npg[:_p] = 1 if npg[:_p] < 1
        else
          npg[:_p] = 1
        end
      else
        npg[:_s] = -1
        npg[:_p] = 1
      end

      npg
    end

    protected

    # Get and normalize an action value.
    # If *action* is `nil`, get it from the `action_name` attribute of {#controller} or from {#params}, then
    # return the string representation of the action value.
    #
    # @param action [String,Symbol,nil] The action to normalize
    #  If `nil`, use the value of **:action** from the {#controller} or {#params} attributes.
    #
    # @return [String,nil] Returns the action name, converted to a string.
    
    def normalize_action(action)
      a = if action.nil?
            (@controller && @controller.respond_to?(:action_name)) ? @controller.action_name : params[:action]
          elsif action.is_a?(String)
            action
          elsif action.is_a?(Symbol)
            action.to_s
          else
            nil
          end
      return a
    end
    
    # Create a copy of a hash where all keys have been converted to symbols.
    # The operation is applied recursively to all values that are also hashes.
    # Additionally, the **:id** key (if present) and any key that ends with `_id` are copied to a key with the
    # same name, prepended by an underscore; for example, **:id** is copied to **:_id** and **:user_id** to
    # **:_user_id**.
    #
    # This method is typically used to normalize the {#params} value.
    #
    # @param h [Hash,ActionController::Parameters] The hash to normalize.
    #
    # @return [Hash] Returns a new hash where all keys have been converted to symbols. This operation
    #  is applied recursively to hash values.

    def normalize_params(h)
      hn = {}
      re = /.+_id$/i

      h.each do |hk, hv|
        case hv
        when ActionController::Parameters
          hv = normalize_params(hv)
        when Hash
          hv = normalize_params(hv)
        end

        hn[hk.to_sym] = hv
        shk = hk.to_s
        hn["_#{shk}".to_sym] = (hv.is_a?(String) ? hv.dup : hv) if (shk == 'id') || (shk =~ re)
      end

      hn
    end

    # Check that access checks are enabled and supported.
    #
    # @param action [String,Symbol,nil] The action for which to check for permission.
    # @param obj [Object, Class, nil] The object that makes the `has_permission?` call; if `nil`, the
    #  {#model_class} is used.
    # @param opts [Hash] A hash of options to pass to the access check methods.
    #
    # @return [Boolean] Returns `true` if access checks are enabled, and *obj* responds to `has_permission?`;
    #  otherwise, it returns `false`.

    def do_access_checks?(action, obj = nil, opts = nil)
      !@_disable_access_checks
    end

    # Check that CAPTCHA checks are enabled and supported.
    #
    # @return [Boolean] Returns `true` if CAPTCHA checks are enabled; otherwise, it returns `false`.

    def do_captcha_checks?()
      (@_disable_captcha) ? false : true
    end

    # Build a lookup key in the message catalog.
    #
    # @param key [String] The partial key.
    #
    # @return [String] Returns a key in the message catalog by prepending _key_ with the localization
    #  prefix.

    def localization_key(key)
      "#{localization_prefix}.#{key}"
    end
      
    # Build a query to list objects.
    # This method is expected to return a ActiveRecord::Relation set up according to the query
    # parameters in <i>query_opts</i>. The default implementation returns `nil`; subclasses are
    # expected to override it to return the correct relation instance.
    #
    # @param query_opts [Hash] A hash of query options to build the query.
    #
    # @return [ActiveRecord::Relation, nil] Returns an instance of ActiveRecord::Relation, or `nil`
    #  on error.

    def index_query(query_opts = {})
      nil
    end

    # Generate a result set from an index query.
    # This method is expected to return an array of objects from a relation that was generated by a
    # call to {#index_query}.
    # The default implementation returns `q.to_a`; subclasses may need to process the query results to
    # generate a final result set.
    #
    # @param q [ActiveRecord::Relation] A relation object from which to generate the result set.
    #
    # @return [Array<ActiveRecord::Base>] Returns an array of ActiveRecord instances.

    def index_results(q)
      q.to_a
    end

    # Modify the value returned by {#index}.
    # This method is called by {#index} to give subclasses the ability to modify (typically by augmenting) the
    # standard return value without having to override {#index} itself.
    # The default implementation returns *results*; subclasses that need to make modifications to its value can
    # override it.
    #
    # @param results [Hash] The results value.
    #
    # @option results [Array<ActiveRecord::Base>] :result The results from the query.
    # @option results [Hash] :_pg The pagination controls returned by {#pagination_controls}.
    #
    # @return [Hash] The return value for {#index}.

    def adjust_index_results(results)
      results
    end

    # Callback triggered after an object is created.
    # The defauly implementation is empty; subclasses can implement additional processing by overriding
    # the method.
    #
    # @param [ActiveRecord::Base] obj The newly created object.
    # @param [Hash,ActionController::Parameters] p The parameters that were used to create the object.
    #
    # @return [Boolean] Returns `true` if the operation succeded, `false` otherwise. If `false` is returned,
    #  the method should call {#set_status} to load an appropriate failure status.
    
    def after_create(obj, p)
      return true
    end

    # Callback triggered after an object is updated.
    # The defauly implementation is empty; subclasses can implement additional processing by overriding
    # the method.
    #
    # @param [ActiveRecord::Base] obj The updated object.
    # @param [Hash,ActionController::Parameters] p The parameters that were used to update the object.
    #
    # @return [Boolean] Returns `true` if the operation succeded, `false` otherwise. If `false` is returned,
    #  the method should call {#set_status} to load an appropriate failure status.

    def after_update(obj, p)
      return true
    end

    # @!visibility private
    @_model_class = nil

    # Set the target model class.
    # The service manages instances of this class. For example, the {#get_and_check} method uses this
    # class to look up an object in the database by object identifier (i.e. it calls something like
    #   self.class.model_class.find(self.params[:id])
    # to look up an object of the appropriate class).
    #
    # Subclasses must call this method in the class definition, for example:
    #
    # ```
    #   class MyService < Fl::Core::Service::Base
    #     self.model_class = Fl::MyModel
    #   end
    # ```
    # The initializer will check that the target model class has been defined.
    #
    # @param klass [Class] The target model class.

    def self.model_class=(klass)
      @_model_class = klass
    end

    # The target model class.
    # See {.model_class=}.
    #
    # @return [Class] Returns the model class.

    def self.model_class()
      @_model_class
    end

    # Map parameter keys to their values.
    # Given an array of keys potentially present in *params*, return an array of two-element arrays that
    # contain the key and its value (a missing key maps to `nil`).
    #
    # @param keys [Symbol, Array<Symbol>] The name or names of the key in *params* that contain the values.
    # @param [Hash] params The parameters where to look up the *idname* key used to fetch the object.
    #
    # @return [Array] Returns an array as described above.
    #  For example, if *params* is `{p1: '10', p2: 20}` and *idname* is
    #  `[ :p1, :p2, :p3 ]`, the return value is `[ [ :p1, 10 ], [ :p2, '20' ], [ :p3, nil ] ]`.

    def map_param_keys(keys, params)
      keys = [ keys ] unless keys.is_a?(Array)

      keys.map do |k|
        ks = k.to_s
        ky = k.to_sym
        v = if params.has_key?(ky)
              params[ky]
            elsif params.has_key?(ks)
              params[ks]
            else
              nil
            end
        [ k, v ]
      end
    end

    # Flatten the elements of a params key/value array.
    # Given an array as returned by {#map_param_keys}, return an array where each element has been converted
    # to a string containing the key and value, separated by a colon (`:`).
    #
    # @param kvp [Array] The array of key/value pairs.
    #
    # @return [Array] Returns an array as described above.
    #  For example, if *kvp* is `[ [ :p1, 10 ], [ :p2, '20' ], [ :p3, nil ] ]`.
    #  the return value is `[ 'p1:10', 'p2:20', 'p3:' ]`.

    def flatten_param_keys(kvp)
      kvp.map do |e|
        k, v = e
        "#{k}:#{v}"
      end
    end

    # Look up an object in the database.
    #
    # @param klass [Class] The object class to instantiate.
    # @param idname [Symbol, Array<Symbol>] The name or names of the key in *params* that contain the object
    #  identifier; array elements are tried until a hit.
    # @param [Hash] params The parameters where to look up the *idname* key used to fetch the object.
    #
    # @return [Array] Returns a two-element array containing the object and an array listing the *idname*
    #  elements and the corresponding value in *params*.
    #  If the first element is `nil`, the object was not found.
    #  The elements in the array for the second element are string containing the corresponding *idname*
    #  element and the value in *params*. For example, if *params* is `{p1: '10', p2: 20}` and *idname* is
    #  `[ :p1, :p2, :p3 ]`, the report array is `[ 'p1:10', 'p2:20', 'p3:' ]`.
    #  This last element is used by the error reporter.

    def find_object(klass, idname, params)
      idname = [ idname ] unless idname.is_a?(Array)
      kvp = map_param_keys(idname, params)

      obj = nil
      kvp.each do |e|
        k, v = e
        unless v.nil?
          begin
            obj = klass.find(v)
            break
          rescue ActiveRecord::RecordNotFound => ex
            obj = nil
          end
        end
      end

      [ obj, kvp ]
    end

    private

    def remote_ip
      (@controller) ? @controller.request.env["REMOTE_ADDR"] : nil
    end
  end
end
