require 'json'

module Fl::Core::Service
  # Base class for service object.
  # A service object implements the processing (business) logic of application components; it typically
  # provides the glue between a controller and the underlying data layer.
  #
  # Service objects include access checks for the various operations, so that controllers do not have to
  # perform explicit checks; this streamlines the controller code. Access checking can be turned off
  # by setting the configuration parameter +disable_access_check+ to true.
  # Also, if the service's {#model_class} does not respond to `has_permission?`, no access control
  # is performed.

  class Base
    # The key in the request parameters that contains the CAPTCHA response.
    CAPTCHA_KEY = 'captchaResponse'

    # The service actor.
    # @return [Object] Returns the _actor_ parameter that was passed to the initializer.
    attr_reader :actor

    # The service parameters.
    # @return [ActionController::Parameters] Returns the parameters loaded into this object, as described
    #  in the documentation for the initializer.
    attr_reader :params

    # The service controller.
    # @return [ActionController::Base] Returns the _controller_ parameter that was passed to the initializer.
    attr_reader :controller

    # Initializer.
    #
    # @param actor [Object] The actor (typically an instance of {Fl::Core::Actor}, and more specifically
    #  a {Fl::Core::User}) on whose behalf the service operates. It may be `nil`.
    # @param params [Hash, ActionController::Parameters] The processing parameters. If the value is `nil`,
    #  the parameters are obtained from the `params` property of _controller_. If _controller_ is also
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
      @params = if params.nil?
                  (@controller.nil?) ? {} : @controller.params
                elsif params.is_a?(Hash)
                  ActionController::Parameters.new(params)
                elsif params.is_a?(ActionController::Parameters)
                  params
                else
                  ActionController::Parameters.new({ })
                end

      raise "please define a target model class for #{self.class.name}" unless self.class.model_class

      @_has_instance_permission = (self.model_class.instance_methods.include?(:has_permission?)) ? true : false
      @_has_class_permission = (self.model_class.methods.include?(:has_permission?)) ? true : false

      @_disable_access_checks = (cfg[:disable_access_checks]) ? true : false
      @_disable_captcha = (cfg[:disable_captcha]) ? true : false
    end

    # @!attribute [r] localization_prefix
    # The localization prefix.
    # This string is prefixed to localization strings; it is obtained from the class name by replacing 
    # +::+ with +.+ and then calling +underscore+ on the result.
    # So for example the localization prefix for class +Fl::Core::Service::Asset::MyAsset+ is
    # +fl.core.service.asset.my_asset+.
    #
    # @return [String] Returns the localization prefix as described above.

    def localization_prefix()
      unless @localization_prefix
        @localization_prefix = self.class.name.gsub('::', '.').underscore
      end
      @localization_prefix
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
    #  - *:status* A symbol describing the status of the call; see the constants defined
    #    in {Fl::Core::Service}. A value other than {Fl::Core::Service::OK} implies that the call failed.
    #  - *:code* An integer code associated with the error. This key is currently not generated.
    #  - A hash containing information about the failure (will not be present on success).
    #    This hash is named the same as the value for *:status*; for example, if *:status* is
    #    {Fl::Core::Service::FORBIDDEN}, the key +:forbidden+ is present in the status value.
    #    This hash contains the following keys:
    #    - *:message* A string containing a localized message related to the failure.
    #    - *:details* Additional information about the failure; for example, on operations that manage
    #      an object, this may contain the object's +errors.messages+.

    def status()
      @status.dup
    end

    # Clear the status.
    # The method sets the service in the success status.

    def clear_status()
      @status = { status: Fl::Core::Service::OK }
    end

    # Set the status.
    # The message is placed in the hash by the same name as _status_, under the +:message+ key.
    # For example, a call to
    #   srv.set_status(Fl::Core::Service::FORBIDDEN, 'not allowed')
    # sets up the status as follows:
    #   {
    #     status: Fl::Core::Service::FORBIDDEN,
    #     Fl::Core::Service::FORBIDDEN.to_sym: {
    #       message: 'not allowed'
    #     }
    #   }
    #
    # @param status [Symbol] The status value (for example, {Fl::Core::Service::FORBIDDEN}).
    # @param msg [String] A message to associate with the status.
    # @param details [Hash] Additional information to place in the *:details* for the error.

    def set_status(status, msg, details = nil)
      @status = {} unless @status.is_a?(Hash)
      @status[:status] = status
      m = @status[status.to_sym] || {}
      m[:message] = msg
      # We need to save a copy just in case the caller has passed something like obj.errors.messages,
      # which is reset when the object is reset
      m[:details] = JSON.parse(JSON.generate(details)) if details
      @status[status.to_sym] = m
    end

    # @!attribute [r] success?
    # Checks if the status indicates success.
    #
    # @return [Boolean, nil] Returns `true` if the current status contains a {Fl::Core::Service::OK} value in the
    #  +:status+ key, `false` otherwise. If there is no +:status+ key, returns `nil`.

    def success?()
      return nil unless @status && @status.has_key?(:status)
      (@status[:status] == Fl::Core::Service::OK) ? true : false
    end

    # Check if the class object associated with the service grants a permission.
    # This check is done for operations triggered by the class object, like running the `index`
    # or `create` action.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The permission to check.
    #  See {Fl::Core::Access::Helper.permission_name} for a description of this value.
    # @param ctx [Object] The context to pass to the `has_permission?` method.
    # @param [Symbol] idname The name of the key in _params_ that contains the object identifier.
    #  A `nil` value defaults to **:id**.
    #
    # @return [Boolean] Returns `true` if the service's {#actor} is granted *permission*,
    #  `false` otherwise.
    #  If the {#model_class} does not respond to `has_permission?`, or if permission checking is disabled,
    #  `true` is returned.

    def class_allow_op?(permission, ctx = nil, idname = nil)
      if do_access_checks?(self.model_class)
        if !self.model_class.has_permission?(permission, self.actor, ctx)
          idname = idname || :id
          idv = params["_#{idname}".to_sym]
          idv = params[idname] if idv.nil?
          self.set_status(Fl::Core::Service::FORBIDDEN,
                          I18n.tx(localization_key('forbidden'), id: idv, op: op) )
          return false
        end
      end

      self.clear_status
      true
    end

    # Check if an object grants a permission.
    # This check is done for operations triggered by a class instance, like running the `show`
    # or `update` action.
    #
    # @param obj [Object] The object to check; this is typically an instance of {#model_class}.
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The permission to check.
    #  See {Fl::Core::Access::Helper.permission_name} for a description of this value.
    # @param ctx [Object] The context to pass to the +permission?+ method.
    # @param [Symbol] idname The name of the key in _params_ that contains the object identifier.
    #  A `nil` value defaults to **:id**.
    #
    # @return [Boolean] Returns `true` if the service's {#actor} is granted permission _op_,
    #  `false` otherwise.
    #  If the _obj_ does not respond to +permission?+, or if permission checking is disabled,
    #  `true` is returned.

    def allow_op?(obj, permission, ctx = nil, idname = nil)
      if do_access_checks?(obj)
        if !obj.has_permission?(permission, self.actor, ctx)
          idname = idname || :id
          idv = params["_#{idname}".to_sym]
          idv = params[idname] if idv.nil?
          self.set_status(Fl::Core::Service::FORBIDDEN,
                          I18n.tx(localization_key('forbidden'), id: idv, op: op) )
          return false
        end
      end

      self.clear_status
      true
    end

    # Look up an object in the database, and check if the service's actor has permissions on it.
    # This method uses the **:id** entry in the {#params} to look up the object in the database
    # (using the target model class as the context for `find`).
    # If it does not find the object, it sets the status to {Fl::Core::Service::NOT_FOUND} and
    # returns `nil`.
    # If it finds the object, it then calls {Fl::Core::Access::Access::InstanceMethods#has_permission?}
    # to confirm that the actor has *permission* access to the object.
    # If the permission call fails, it sets the status to {Fl::Core::Service::FORBIDDEN} and returns
    # the object.
    # Otherwise, it sets the status to {Fl::Core::Service::OK} and returns the object.
    #
    # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The permission to check.
    #  See {Fl::Core::Access::Helper.permission_name} for a description of this value.
    #  If `nil`, no access check is performed and the call is the equivalent of a simple database lookup.
    # @param [Symbol] idname The name of the key in _params_ that contains the object identifier.
    #  A `nil` value defaults to **:id**.
    # @param [Hash] params The parameters where to look up the **:id** key used to fetch the object.
    #  If `nil`, use the _params_ value that was passed to the constructor.
    # @option [Object] context The context to pass to the access checker method {#allow_op?}.
    #  The special value +:params+ (a Symbol named +params+) indicates that the value of _params_ is to be
    #  passed as the context.
    #  Defaults to `nil`.
    #
    # @return [Object, nil] Returns an object, or `nil`. Note that a non-nil return value is not a guarantee
    #  that the check operation succeded.

    def get_and_check(permission, idname = nil, params = nil, context = nil)
      idname = idname || :id
      params = params || self.params
      ctx = (:context == :params) ? params : context

      begin
        obj = self.model_class.find(params[idname])
      rescue => ex
        idv = params["_#idname}".to_sym]
        idv = params[idname] if idv.nil?
        self.set_status(Fl::Core::Service::NOT_FOUND,
                        I18n.tx(localization_key('not_found'), id: idv))
        return nil
      end

      self.clear_status if allow_op?(obj, permission, ctx, idname)
      obj
    end

    # Run a CAPTCHA verification.
    # CAPTCHA verification is performed as follows:
    #
    # 1. If the ckecks are disabled, return a success value.
    # 2. Look up the key +captchaResponse+ in {#create_params}, and if not found
    #    sets the status to {Fl::Core::Service::UNPROCESSABLE_ENTITY} and return a failure value.
    # 3. Creates an instance of the CAPTCHA verifier using {Fl::Core::CAPTCHA.factory} and calls
    #    its {Fl::Core::CAPTCHA::Base#verify} method.
    #    On error, sets the status to {Fl::Core::Service::UNPROCESSABLE_ENTITY}.
    # 4. Return the response form the verification method.
    #
    # Note that verification failures have the side effect of setting the status, so that clients can use
    # {#success?} or check the +success+ field in the return value to determine if the call was successful.
    #
    # @param [Boolean,Hash] opts The CAPTCHA options. If `nil` or `false`, return a success value: no
    #  verification is requested. If a hash or `true`, run the verification; the hash value is passed
    #  to the {Fl::Core::CAPTCHA::Base} initializer.
    #
    # @return [Hash] Returns a hash with the same structure as the return value from
    #  {Fl::Core::CAPTCHA::Base#verify}.

    def verify_captcha(opts, params)
      return { 'success' => true } unless do_captcha_checks?

      if opts
        captcha = params.delete(CAPTCHA_KEY)
        if captcha.is_a?(String) && (captcha.length > 0)
          rq = Fl::Core::CAPTCHA.factory((opts.is_a?(Hash)) ? opts : {})
          rv = rq.verify(captcha, remote_ip)
          unless rv['success']
            self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                            I18n.tx("fl.core.captcha.verification-failure",
                                    messages: rv['error-messages'].join(', ')))
          end
          rv
        else
          self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                          I18n.tx("fl.core.captcha.no-captcha", key: CAPTCHA_KEY))
          { 'success' => false, 'error-codes' => [ 'no-captcha' ] }
        end
      else
        { 'success' => true }
      end
    end

    # Create an instance of the model class.
    # This method attempts to create and save an instance of the model class; if either operation fails,
    # it sets the status to {Fl::Core::Service::UNPROCESSBLE_ENTITY} and loads a message and the
    # **:details** key in the error status from the object's **errors**. 
    #
    # The method calls {#class_allow_op?} for `opts[:permission]` to confirm that the
    # service's *actor* has permission to create objects. If the permission is not granted, `nil` is returned.
    #
    # If an object is created successfully, the method calls {#after_create} to give subclasses a hook
    # to perform additional processing.
    #
    # @param opts [Hash] Options to the method. This section describes the common options; subclasses may
    #  define type-specific ones.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to the object's
    #  initializer. If not present or `nil`, use the value returned by {#create_params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate subclass of {Fl::CAPTCHA::Base}
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to the initializer for {Fl::CAPTCHA::Base}.
    # @option opts [Symbol,String,Fl::Core::Access::Permission,Class] :permission The permission
    #  to request in order to complete the operation.
    #  See {Fl::Core::Access::Helper.permission_name}.
    #  Defaults to {Fl::Core::Access::Permission::Create::NAME}.
    # @option opts [Object] :context The context to pass to the access checker method {#class_allow_op?}.
    #  The special value **:params** (a Symbol named `params`) indicates that the create parameters are to be
    #  passed as the context.
    #  Defaults to **:params**.
    #
    # @return [Object, nil] Returns an instance of the {#model_class}. Note that a non-nil return value
    #  does not indicate that the call was successful; for that, you should call {#success?} or check if
    #  the instance is valid.

    def create(opts = {})
      p = (opts[:params]) ? opts[:params].to_h : create_params(self.params).to_h
      op = (opts[:permission]) ? opts[:permission] : Fl::Core::Access::Permission::Create::NAME
      ctx = if opts.has_key?(:context)
              (opts[:context] == :params) ? p : opts[:context]
            else
              # This is equivalent to setting the default to :params

              p
            end

      if class_allow_op?(op, ctx)
        rs = verify_captcha(opts[:captcha], p)
        if rs['success']
          begin
            obj = self.model_class.new(p)
            if obj.save
              after_create(obj, p)
            else
              self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                              I18n.tx(localization_key('creation_failure')),
                              (obj) ? obj.errors.messages : nil)
            end
          rescue => exc
            self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                            I18n.tx(localization_key('creation_failure')),
                            { message: exc.message })
            obj = nil
          end

          obj
        else
          nil
        end
      else
        nil
      end
    end
    
    # Update an instance of the model class.
    # This method attempts to update an instance of the model class; if the operation fails,
    # it sets the status to {Fl::Core::Service::UNPROCESSBLE_ENTITY} and loads a message and the
    # **:details** key in the error status from the object's +errors+. 
    #
    # The method calls {#allow_op?} for `opts[:permission]` to confirm that the
    # service's _actor_ has permission to update the object.
    # If the permission is not granted, `nil` is returned.
    #
    # @param opts [Hash] Options to the method. This section describes the common options; subclasses may
    #  define type-specific ones.
    # @option opts [Symbol,String] :idname The name of the key in {#params} that contains the object
    #  identifier.
    #  Defaults to **:id**.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to the object's
    #  initializer. If not present or `nil`, use the value returned by {#update_params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate subclass of {Fl::CAPTCHA::Base}
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to the initializer for {Fl::CAPTCHA::Base}.
    # @option opts [Symbol,String] :permission The name of the permission to request in order to
    #  complete the operation. Defaults to {Fl::Core::Access::Grants::WRITE}.
    # @option opts [Object] :context The context to pass to the access checker method {#class_allow_op?}.
    #  The special value +:params+ (a Symbol named +params+) indicates that the create parameters are to be
    #  passed as the context.
    #  Defaults to +:params+.
    #
    # @return [Object, nil] Returns the updated object. Note that a non-nil return value
    #  does not indicate that the call was successful; for that, you should call {#success?} or check if
    #  the instance is valid.

    def update(opts = {})
      p = (opts[:params]) ? opts[:params].to_h : update_params(self.params).to_h
      op = (opts[:permission]) ? opts[:permission] : Fl::Core::Access::Permission::Write::NAME
      ctx = if opts.has_key?(:context)
              (opts[:context] == :params) ? p : opts[:context]
            else
              # This is equivalent to setting the default to :params

              p
            end
      idname = (opts[:idname]) ? opts[:idname].to_sym : :id

      obj = get_and_check(op, idname)
      if obj && success?
        rs = verify_captcha(opts[:captcha], p)
        if rs['success']
          begin
            unless obj.update_attributes(p)
              self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                              I18n.tx(localization_key('update_failure')),
                              (obj) ? obj.errors.messages : nil)
            end
          rescue => exc
            self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                            I18n.tx(localization_key('update_failure')),
                            { details: { message: exc.message } })
          end
        else
          obj = nil
        end
      else
        obj = nil
      end

      obj
    end

    # Convert parameters to `ActionController::Parameters`.
    # This method expects *p* to contain a hash, or a JSON representation of a hash, of parameters,
    # and converts it to `ActionController::Parameters`.
    # Therefore, it performs these steps:
    #
    # 1. If *p* is `nil`, it uses the value of {#params}.
    # 2. It then checks if it is a string value; in that case, it assumes that the client has generated
    #    a JSON representation of the parameters, and parses it into a hash.
    # 3. If the value is already a `ActionController::Parameters`, it returns it as is;
    #    otherwise, it constaructs a new `ActionController::Parameters` instance from the hash value.
    #
    # @param p [Hash,ActionController::Parameters,String,nil] The parameters to convert.
    #  If a string value, it is assumed to contain a JSON representation.
    #  If `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the converted parameters.

    def strong_params(p = nil)
      sp = (p.nil?) ? self.params : p
      sp = JSON.parse(sp) if sp.is_a?(String)
      (sp.is_a?(ActionController::Parameters)) ? sp : ActionController::Parameters.new(sp)
    end

    # Get create parameters.
    # This method is meant to be overridden by subclasses to implement class-specific lookup of creation
    # parameters. A typical implementation uses the Rails strong parameters functionality, as in the
    # example below.
    #
    # ```
    #   def create_params(p)
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
    #   def update_params(p)
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
    #  parameters subset. If `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the standard permitted `to_hash` parameters.

    def to_hash_params(p = nil)
      strong_params(strong_params(p).fetch(:to_hash, { })).permit(:as_visible_to, :verbosity,
                                                                  { only: [ ] }, { include: [ ] },
                                                                  { except: [ ] }, { image_sizes: [ ] },
                                                                  { to_hash: { } })
    end

    protected

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
    # The method catches any exceptions and sets the error state of the service from the
    # exception properties.
    #
    # @param query_opts [Hash] Query options to merge with the contents of <i>_q</i> and <i>_pg</i>.
    #  This is used to define service-specific defaults.
    # @param _q [Hash, ActionController::Parameters] The query parameters.
    # @param _pg [Hash, ActionController::Parameters] The pagination parameters.
    #
    # @return [Hash, nil] If a query is generated, it returns a Hash containing two keys:
    #  - *:results* are the results from the query; this is an array of objects.
    #  - *:_pg* are the pagination controls returned by {#pagination_controls}.
    #  If no query is generated (in other words, if {#index_query} fails), it returns `nil`.
    #  It also returns `nil` if an exception was raised.

    def index(query_opts = {}, _q = {}, _pg = {})
      begin
        qo = init_query_opts(query_opts, _q, _pg)
        q = index_query(qo)
        if q
          r = index_results(q)
          return {
            result: r,
            _pg: pagination_controls(r, qo, self.params)
          }
        end
      rescue => exc
        self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY, exc.message)
        return nil
      end
    end

    # Initialize the query options for the **:index** action.
    # This methods merges the contents of the *:_q* and *:_pg* keys in the submission parameters into the
    # default backstops.
    # It also converts some values to a canonical form (for example, integer-valued options are converted
    # to integer values).
    #
    # The value of the *:_q* key is a hash of options for the :index action. The value of the *:_pg* key is
    # a hash containing pagination control values:
    # - *:_s* is the page size (the number of items to return); a negative value means to return all items.
    # - *:_p* is the 1-based index of the page to return; the first page is at index 1.
    #
    # The method builds the query options as follows:
    #
    # 1. Set up default values for the query options from _defs_ and the {QUERY_BACKSTOPS}.
    # 2. The values in *_pg* (if any) are used to initialize the values for *:offset* and *:limit* in
    #    the query options: *:limit* is the value of the *:_s* key, and *:offset* is
    #    `(_pg[_p] - 1) * :limit`.
    # 3. Merge the values in *\_q* into the query options; *:offset* and *:limit* override the values
    #    from the previous step. Additionally, if *:limit* is negative, then *\_pg* is ignored;
    #    for example, if *:_s* is 4, *:_pg* is 2, *:limit* is -1, and *:offset* is 4, then the new value
    #    of *\_pg* is `{ _s: -1, _p: 1 }`. See {#pagination_controls}.
    # 4. If the value of *:limit* is negative, *:limit* is removed from the query options.
    #
    # @param defs [Hash] A hash of default values for the options, which override the following backstops:
    #
    #  - *:offset* is 0.
    #  - *:limit* is 20. If the value in _defs_ is -1, *:limit* is not placed in the query options.
    #  - *:order* is <tt>updated_at DESC</tt>.
    #  Any other keys in _defs_ provide the backstop, and the method looks up an overriding
    #  value in <i>_q</i> and <i>_pg</i>.
    # @param _q [Hash] The query parameters, from the *:_q* key in the submission parameters.
    # @param _pg [Hash] The pagination parameters, from the *:_pg* key in the submission parameters.
    #
    # @return [Hash] Returns a hash of query options.

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

      opts
    end

    # Generate pagination control data for the next page in an :index query.
    # This methods generates a pagination control hash from the values of the options to an :index query.
    #
    # The method builds the pagination controls as follows:
    #
    # 1. Initialize with the values from *:_pg* in _opts_, if any.
    # 2. Set the value of *:_c* to the length of the _results_ array, or to 0 if _results_ is `nil`.
    # 3. If _opts_ does not have a *:limit* value, set *:_s* to -1 and *:_p* to 1, since we cannot determine
    #    the page size and therefore calculate a starting page from the *:offset* option.
    # 4. Otherwise, set *:_s* to the value of *:limit* in _opts_, and *:_p* to the next page, based on the
    #    value of *:offset* and *:limit*.
    # Note that setting *:offset* or *:limit* (or both) in _opts_ may cause the pagination controls to be
    # inaccurate. Clients that use these two options should not rely on the pagination controls.
    #
    # @param results [Array, nil] An array containing the results from the query.
    # @param opts [Hash] A hash containing query options.
    # @param pars [Hash] The submission query parameters. If `nil`, the controller's +params+ value is used.
    #
    # @return [Hash] Returns a hash containing the pagination controls: *:_s* is the page size, *:_p* is the
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

    # Create a copy of a hash where all keys have been converted to symbols.
    # The operation is applied recursively to all values that are also hashes.
    # Additionally, the *:id* key (if present) and any key that ends with +_id+ are copied to a key with the
    # same name, prepended by an underscore; for example, *:id* is copied to *:_id* and *:user_id* to
    # *:_user_id*.
    #
    # This method is typically used to normalize the +params+ value.
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
    # @param obj [Object, Class, nil] The object that makes the +permission?+ call; if `nil`, the
    #  {#model_class} is used.
    #
    # @return [Boolean] Returns `true` if access checks are enabled, and _obj_ responds to +permission?+;
    #  otherwise, it returns `false`.

    def do_access_checks?(obj = nil)
      obj = self.model_class if obj.nil?
      (@_disable_access_checks || !obj.respond_to?(:permission?)) ? false : true
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
      localization_prefix + '.' + key
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

    # Callback triggered after an object is created.
    # The defauly implementation is empty; subclasses can implement additional processing by overriding
    # the method.
    #
    # @param [ActiveRecord::Base] obj The newly created object.
    # @param [Hash,ActionController::Parameters] p The parameters that were used to create the object.

    def after_create(obj, p)
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

    private

    def remote_ip
      (@controller) ? @controller.request.env["REMOTE_ADDR"] : nil
    end
  end
end
