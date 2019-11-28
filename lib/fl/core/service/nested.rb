module Fl::Core::Service
  # Base class for service objects that are "nested" inside others.
  # This class implements functionality used by objects that map to nested resources, like for example
  # comments associated with a commentable.

  class Nested < Base
    # Initializer.
    #
    # @param owner_class [Class] The class object of the owner. Since it is possible to nest objects
    #  within different owners, we need to provide the class at the instance level, rather than at the
    #  class level as we do fo the model class. An example of a nested object that takes multiple owner
    #  types is a comment, which can be created in the context of multiple commentables.
    # @param actor [Object] The actor (typically an instance of {Fl::Core::Actor}, and more specifically
    #  a {Fl::Core::User}) on whose behalf the service operates. It may be +nil+.
    # @param params [Hash, ActionController::Parameters] The processing parameters. If the value is +nil+,
    #  the parameters are obtained from the `params` property of _controller_. If _controller_ is also
    #  +nil+, the value is set to an empty hash. Hash values are converted to `ActionController::Parameters`.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options.
    # @option cfg [Boolean] :disable_access_checks Controls the access checks: set it to +true+ to
    #  disable access checking. The default value is +false+.
    # @option cfg [Boolean] :disable_captcha Controls the CAPTCHA checks: set it to +true+ to
    #  disable verification, even if the individual method options requested.
    #  This is mainly used during testing. The default value is +false+.

    def initialize(owner_class, actor, params = nil, controller = nil, cfg = {})
      @owner_class = owner_class
      super(actor, params, controller, cfg)
    end

    # @!attribute [r] owner_class
    # The owner class.
    # Wraps a call to {.owner_class}.
    #
    # @return [Class] Returns the owner class.

    def owner_class()
      @owner_class
    end

    # Look up an owner in the database, and check if the service's actor has permissions on it.
    # This method uses the owner id entry in the {#params} to look up the object in the database
    # (using the owner model class as the context for +find+, and the value of _idname_ as the lookup
    # key).
    # If it does not find the object, it sets the status to {Fl::Core::Service::NOT_FOUND} and
    # returns +nil+.
    # If it finds the object, it then calls {Fl::Core::Access::Access::InstanceMethods#permission?} to
    # confirm that the actor has _op_ access to the object.
    # If the permission call fails, it sets the status to {Fl::Core::Service::FORBIDDEN} and returns the
    # object.
    # Otherwise, it sets the status to {Fl::Core::Service::OK} and returns the object.
    #
    # @param [Symbol,nil] op The operation for which to request permission.
    #  If +nil+, no access check is performed and the call is the equivalent of a simple database lookup.
    # @param [Symbol, Array<Symbol>] idname The name or names of the key in _params_ that contain the object
    #  identifier for the owner. A +nil+ value defaults to +:owner_id+.
    # @param [Hash] params The parameters where to look up the +:id+ key used to fetch the object.
    #  If +nil+, use the value returned by {#params}.
    # @option [Object] context The context to pass to the access checker method {#allow_op?}.
    #  The special value +:params+ (a Symbol named +params+) indicates that the value of _params_ is to be
    #  passed as the context.
    #  Defaults to +nil+.
    #
    # @return [Object, nil] Returns an object, or +nil+. Note that a non-nil return value is not a guarantee
    #  that the check operation succeded. The object class will be the value of the owner_class parameter
    #  to {#initialize}.

    def get_and_check_owner(op, idname = nil, params = nil, context = nil)
      idname = idname || :owner_id
      idname = [ idname ] unless idname.is_a?(Array)
      params = params || self.params
      ctx = (:context == :params) ? params : context

      obj = nil
      idname.each do |idn|
        if params.has_key?(idn)
          begin
            obj = self.owner_class.find(params[idn])
            break
          rescue ActiveRecord::RecordNotFound => ex
            obj = nil
          end
        end
      end

      if obj.nil?
        self.set_status(Fl::Core::Service::NOT_FOUND,
                        I18n.tx(localization_key('no_owner'), id: idname.join(',')))
        return nil
      end

      self.clear_status if allow_op?(obj, op, ctx)
      obj
    end

    # Create a model for a given owner.
    # This method is used for classes created within the "context" of another class, as is the case for
    # nested resources. For example, say we have a +Story+ object that is associated with a +User+ author,
    # and the story controller is nested inside the user context.
    # The resource URL for creating stories, then, looks like +/users/1234/stories+, where +1234+ is the
    # user's identifier; the route pattern is +/users/:user_id/stories+.
    # The story object has an attribute +:author+ that contains the story's author, which in this case is
    # set to the user that corresponds to +:user_id+.
    # With all that in mind, the value for *:owner_id_name* is +:user_id+, and for
    # *:owner_attribute_name* it is +:author+.
    #
    # The method attempts to create and save an instance of the model class; if either operation fails,
    # it sets the status to UNPROCESSABLE_ENTITY and loads a message and the *:details* key in the error status
    # from the object's errors.
    #
    # @param opts [Hash] Options to the method. This section describes the common options; subclasses may
    #  define type-specific ones.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to the object's
    #  initializer. If not present or +nil+, use the value returned by {#create_params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either +true+ or a hash,
    #  the method does a CAPTCHA validation using an appropriate subclass of {Fl::CAPTCHA::Base}
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to the initializer for {Fl::CAPTCHA::Base}.
    # @option opts [Symbol,String] :permission The name of the permission to request in order to
    #  complete the operation. Defaults to {Fl::Core::Access::Grants::CREATE}.
    # @option opts [Object] :context The context to pass to the access checker method {#class_allow_op?}.
    #  The special value +:params+ (a Symbol named +params+) indicates that the create parameters are to be
    #  passed as the context.
    #  Defaults to +:params+.
    # @option opts [Symbol,String] :owner_id_name The name of the parameter in {#params} that
    #  contains the object identifier for the owner. Defaults to +:owner_id+.
    # @option opts [Symbol,String] :owner_attribute_name The name of the attribute passed to the initializer
    #  that contains the owner object. Defaults to +:owner+.
    #
    # @return [Object] Returns the created object on success, +nil+ on error.
    #  Note that a non-nil return value does not indicate that the call was successful; for that, you should
    #  call #success? or check if the instance is valid.

    def create_nested(opts = {})
      idname = (opts.has_key?(:owner_id_name)) ? opts[:owner_id_name].to_sym : :owner_id
      attrname = (opts.has_key?(:owner_attribute_name)) ? opts[:owner_attribute_name].to_sym : :owner
      p = (opts[:params]) ? opts[:params].to_h : create_params(self.params).to_h
      op = (opts[:permission]) ? opts[:permission].to_sym : Cf::Core::User::ACCESS_BOOKMARK_CREATE
      ctx = if opts.has_key?(:context)
              (opts[:context] == :params) ? p : opts[:context]
            else
              # This is equivalent to setting the default to :params

              p
            end

      owner = get_and_check_owner(op, idname, nil, ctx)
      obj = nil
      if owner && success?
        rs = verify_captcha(opts[:captcha], p)
        if rs['success']
          if allow_op?(owner, op, ctx)
            p[attrname] = owner
            obj = self.model_class.new(p)
            unless obj.save
              self.set_status(Fl::Core::Service::UNPROCESSABLE_ENTITY,
                              I18n.tx(localization_key('creation_failure'), owner: owner.fingerprint),
                              (obj) ? obj.errors.messages : nil)
            end
          end
        end
      end

      obj
    end
  end
end
