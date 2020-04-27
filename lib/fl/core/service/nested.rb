module Fl::Core::Service
  # Base class for service objects that are "nested" inside others.
  # This class implements functionality used by objects that map to nested resources, like for example
  # comments associated with a commentable.

  class Nested < Base
    # Initializer.
    #
    # @param parent_class [Class] The class object of the parent. Since it is possible to nest objects
    #  within different parents, we need to provide the class at the instance level, rather than at the
    #  class level as we do for the model class. An example of a nested object that takes multiple parent
    #  types is a comment, which can be created in the context of multiple commentables.
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
    # @option cfg [Symbol,String] :parent_id_name The name of the key in {#params} that holds the
    #  object identifier of the parent resource. For example, if the route path is
    #  `/my/things/:thing_id/others`, then a path `/my/things/1234/others` results in the key **:thing_id**
    #  with value `'1234'` in {#params}.
    #  If this option is not provided, the key is set to the last component in the parent class name, underscored and
    #  with a `_id` postfix. So if the parent class is `My::Thing`, then the **:parent_id_name** is
    #  `thing_id`.
    #
    # @raise Raises an exception if the target model class has not been defined.

    def initialize(parent_class, actor, params = nil, controller = nil, cfg = {})
      @parent_class = parent_class
      @parent_id_name = (cfg[:parent_id_name] || generate_parent_id_name).to_sym
      @parent = nil
      
      super(actor, params, controller, cfg)
    end

    # @!attribute [r] parent_class
    # The parent class.
    #
    # @return [Class] Returns the parent class.

    attr_reader :parent_class

    # @!attribute [r] parent_id_name
    # The name of the key in {#params} that holds the identifier for the parent object.
    #
    # @return [Symbol] Returns the name of the key that holds the parent object identifier.

    attr_reader :parent_id_name

    protected

    # @!attribute parent [r]
    # The parent object. This value is set by {#get_and_check_parent}.
    #
    # @return [ActiveRecord::Base] The parent.

    attr_reader :parent

    public
    
    # Look up an parent in the database.
    # This method uses the parent id entry in {#params} to look up the object in the database
    # (using the parent model class as the context for `find`, and the value of *idname* as the lookup key).
    # If it does not find the object, it sets the status to {Fl::Core::Service::NOT_FOUND} and
    # returns `nil`.
    # If it finds the object, it caches it and then returns it.
    #
    # The parent object is available to subclasses via the {#parent} attribute.
    # If the method is called twice, the cached object is returned directly.
    #
    # @param idname [Symbol, Array<Symbol>] The name or names of the key in *params* that contain the object
    #  identifier for the parent; array elements are tried until a hit. A `nil` value defaults to {#parent_id_name}.
    # @param [Hash] params The parameters where to look up the *idname* key used to fetch the object.
    #  If `nil`, use the value returned by {#params}.
    #
    # @return [ActiveRecord::Base, nil] Returns the master object, or `nil` if the parent was not found.

    def get_parent(idname = nil, params = nil)
      return @parent if !@parent.nil?
      
      idname = idname || parent_id_name
      params = normalize_params(params || self.params)

      @parent, kvp = find_object(self.parent_class, idname, params)
      if @parent.nil?
        self.set_status(Fl::Core::Service::NOT_FOUND,
                        error_response_data('no_parent',
                                            localized_message('parent_not_found', id: flatten_param_keys(kvp).join(','))))
        return nil
      end
      
      @parent
    end
    
    # Look up an parent in the database, and check if the service's actor has permissions on it.
    # This method calls {#get_parent} and, if the return value is non-nil,
    # it then calls {Fl::Core::Access::Access::InstanceMethods#has_permission?} to
    # confirm that the actor has *op* access to the object.
    # If the permission call fails, it sets the status to {Fl::Core::Service::FORBIDDEN} and returns the
    # object.
    # Otherwise, it sets the status to {Fl::Core::Service::OK} and returns the object.
    #
    # The parent object is also cached, and is available to subclasses via tyhe {#parent} attribute.
    # If the method is called twice, the cached object is used for access control.
    #
    # @param action [String,Symbol,nil] The action for which to check for permission.
    #  If `nil`, no access check is performed and the call is the equivalent of a simple database lookup.
    # @param idname [Symbol, Array<Symbol>] The name or names of the key in *params* that contain the object
    #  identifier for the parent; array elements are tried until a hit. A `nil` value defaults to {#parent_id_name}.
    # @param [Hash] pars The parameters where to look up the *idname* key used to fetch the object.
    #  If `nil`, use the value returned by {#params}.
    # @option [Object] context The context to pass to the access checker method {#has_action_permission?}.
    #  The special value **:params** (a Symbol named `params`) indicates that the value of _params_ is to be
    #  passed as the context.
    #  Defaults to +nil+.
    #
    # @return [Object, nil] Returns an object, or +nil+. Note that a non-nil return value is not a guarantee
    #  that the check operation succeded. The object class will be the value of the parent_class parameter
    #  to {#initialize}.

    def get_and_check_parent(action, idname = nil, pars = nil, context = nil)
      obj = get_parent(idname, pars)
      return nil if obj.nil?
      
      if !action.nil?
        self.clear_status if has_action_permission?(action, obj, context)
      end
      
      obj
    end

    # Create a model for a given parent.
    # This method is used for classes created within the "context" of another class, as is the case for
    # nested resources. For example, say we have a `Story` object that is associated with a `User` author,
    # and the story controller is nested inside the user context.
    # The resource URL for creating stories, then, looks like `/users/1234/stories`, where `1234` is the
    # user's identifier; the route pattern is `/users/:user_id/stories`.
    # The story object has an attribute `:author` that contains the story's author, which in this case is
    # set to the user that corresponds to `:user_id`.
    # With all that in mind, the value for **:parent_id_name** is `:user_id`, and for
    # **:parent_attribute_name** it is `:author`.
    #
    # The method attempts to create and save an instance of the model class; if either operation fails,
    # it sets the status to {Fl::Core::Service::UNPROCESSABLE_ENTITY} and loads an error response data hash
    # that includes the object's error messages.
    #
    # Note that the method uses {#get_and_check_parent} with action `create` to confirm that the actor does
    # have permission to create a nested object instance.
    #
    # @param opts [Hash] Options to the method. This section describes the common options; subclasses may
    #  define type-specific ones.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to the object's
    #  initializer. If not present or `nil`, use the value returned by {#create_params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate CAPTCHA object
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to {Fl::Core::CAPTCHA.factory}.
    # @option opts [Object] :context The context to pass to the access check method {#has_action_permission?}.
    #  The special value `:params` (a Symbol named `params`) indicates that the create parameters are to be
    #  passed as the context.
    #  Defaults to `:params`.
    # @option opts [Symbol,String] :parent_id_name The name of the parameter in {#params} that
    #  contains the object identifier for the parent. Defaults to `:parent_id`.
    # @option opts [Symbol,String] :parent_attribute_name The name of the attribute passed to the initializer
    #  that contains the parent object. Defaults to `:parent`.
    #
    # @return [Object] Returns the created object on success, `nil` on error.
    #  Note that a non-nil return value does not indicate that the call was successful; for that, you should
    #  call {#success?} or check if the instance is valid.

    def create_nested(opts = {})
      idname = (opts.has_key?(:parent_id_name)) ? opts[:parent_id_name].to_sym : :parent_id
      attrname = (opts.has_key?(:parent_attribute_name)) ? opts[:parent_attribute_name].to_sym : :parent
      p = (opts[:params]) ? opts[:params].to_h : create_params(self.params).to_h
      ctx = if opts.has_key?(:context)
              (opts[:context] == :params) ? p : opts[:context]
            else
              # This is equivalent to setting the default to :params

              p
            end

      parent = get_parent(idname, nil)
      obj = nil
      if parent && success?
        begin
          rs = verify_captcha(opts[:captcha], p)
          if rs['success']
            if has_action_permission?('create', parent, ctx)
              p[attrname] = parent
              obj = self.model_class.new(p)
              unless obj.save
                self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                                error_response_data('nested_creation_failure',
                                                    localized_message('nested_creation_failure',
                                                                      parent: parent.fingerprint,
                                                                      class: self.model_class.name),
                                                    (obj) ? obj.errors.messages : nil))
              end
            end
          end
        rescue => exc
          self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                          error_response_data('creation_failure',
                                              localized_message('creation_failure', class: self.model_class.name),
                                              { message: exc.message }))
        end
      end

      return obj
    end

    protected

    # Check that access checks are enabled and supported.
    # Overrides the base implementation to ignore *obj* and use the {#parent} instead.
    #
    # @param action [String,Symbol,nil] The action for which to check for permission.
    # @param obj [Object, Class, nil] The object that makes the `has_permission?` call; if `nil`, the
    #  {#model_class} is used.
    # @param opts [Hash] A hash of options to pass to the access check methods.
    #
    # @return [Boolean] Returns `true` if access checks are enabled, and *obj* responds to `has_permission?`;
    #  otherwise, it returns `false`.

    def do_access_checks?(action, obj = nil, opts = nil)
      obj = get_parent if !obj.is_a?(parent_class)
      (_disable_access_checks || !obj.respond_to?(:has_permission?)) ? false : true
    end

    # Perform the permission check for an action.
    # Overrides the base implementation for the following actions:
    #
    # - **index** uses {Fl::Core::Access::Permission::IndexContents} if *obj* is a class instance rather than
    #   a class. In nested service implementations, *obj* is the parent object, and controls access for the
    #   dependent objects.
    # - **create** uses {Fl::Core::Access::Permission::Write} if *obj* is a class instance rather than
    #   a class. In nested service implementations, *obj* is the parent object, and controls access for the
    #   dependent objects.
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
      case action
      when 'index'
        if obj.is_a?(Class)
          return obj.has_permission?(Fl::Core::Access::Permission::Index::NAME, self.actor, opts)
        else
          return obj.has_permission?(Fl::Core::Access::Permission::IndexContents::NAME, self.actor, opts)
        end          
      when 'create'
        if obj.is_a?(Class)
          return obj.has_permission?(Fl::Core::Access::Permission::Create::NAME, self.actor, opts)
        else
          return obj.has_permission?(Fl::Core::Access::Permission::Write::NAME, self.actor, opts)
        end
      else
        return super(action, obj, opts)
      end
    end

    # Generate the name of the parent id parameter from the current value os the parent class.
    #
    # @return [Symbol] Returns the parent id name.

    def generate_parent_id_name()
      "#{@parent_class.name.split('::').last.underscore}_id".to_sym
    end
  end
end
