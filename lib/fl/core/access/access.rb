module Fl::Core::Access
  # Access control APIs.
  # This module adds support for access control to a class.
  # When it is included, it defines the macro {ClassMacros#has_access_control}, which turns on access
  # control support in the class.
  # When access control is enabled, a number of instance and class methods are registered; see the
  # documentation for {ClassMethods} and {InstanceMethods}.
  #
  # The methods in this module define and implement a framework for standardizing access control
  # management, but don't provide a specific access control algorithm, and don't enforce access
  # control at the record level. (That functionality is left to a higher level layer, typically in a
  # service object.)
  # Classes define the access check strategy by providing an instance of (a subclass of)
  # {Checker} to {ClassMacros#has_access_control}.
  #
  # The APIs use a generic object called an *actor* as the entity that requests permission to perform
  # a given operation on an object. The type of *actor* is left undefined, and it is expected that
  # clients of this framework will provide their own specific types. Typically, this will be some kind of
  # user object, but it may be a software agent as well. The framework mostly passes the actor parameter
  # down to the access checkers that implement the specialized access control algorithms; these checkers
  # should be aware of the nature of the actor entity.
  #
  # The access package also defines a number of standard permissions; see the documentation for the
  # {Permission} class.
  #
  # To enable access control, define an access checker subclass and pass it to
  # {ClassMacros#has_access_control}:
  #
  # ```
  # class MyAccessChecker < Fl::Core::Access::Checker
  #   def access_check(permission, actor, asset, context = nil)
  #     # here is the access check code
  #   end
  # end
  #
  # class MyDatum < ActiveRecord::Base
  #   include Fl::Core::Access::Access
  #
  #   has_access_control MyAccessChecker.new
  # end
  # ```
  #
  # You can also add acces control to an existing class, using {Helper.add_access_control}:
  #
  # ```
  # class MyAccessChecker < Fl::Core::Access::Checker
  #   def access_check(permission, actor, asset, context = nil)
  #     # here is the access check code
  #   end
  # end
  #
  # class MyDatum < ActiveRecord::Base
  # end
  #
  # Fl::Core::Access::Helper.add_access_control(MyDatum, MyAccessChecker.new)
  # ```

  module Access
    # The methods in this module will be installed as class methods of the including class.
    # Of particular importance is {#has_access_control}, which is used to turn on access control for
    # the class.

    module ClassMacros
      # Turn on access control for a class.
      # This method registers the given access checker with the class.
      # It then injects the methods in {ClassMethods} as class methods, and those in
      # {InstanceMethods} as instance methods.
      # Finally, it calls {Fl::Core::Access::Checker#configure} on *checker*, passing `self`;
      # the checker may modify the class declaration as needed.
      #
      # @param checker [Fl::Core::Access::Checker] The checker to use for access control.
      # @param opts [Hash] A hash containing configuration parameters.
      #
      # @raise [RuntimeError] Raises an exception if *checker* is not an instance of {Checker}.
      
      def has_access_control(checker, *opts)
        unless checker.is_a?(Fl::Core::Access::Checker)
          raise "access checker is a #{checker.class.name}, should be a Fl::Core::Access::Checker"
        end
        
        self.class_variable_set(:@@_access_checker, checker)

        self.send(:extend, Fl::Core::Access::Access::ClassMethods)
        self.send(:include, Fl::Core::Access::Access::InstanceMethods)

        checker.configure(self)
      end

      # Get the access checker.
      #
      # @return [Fl::Core::Access::Checker] Returns the value that was passed to {#has_access_control}.

      def access_checker()
        self.class_variable_get(:@@_access_checker)
      end
    end

    # The methods in this module are installed as class method of the including class.
    # Note that these methods are installed by {ClassMacros#has_access_control}, so that only classes
    # that use access control implement these methods.

    module ClassMethods
      # Check if this model supports access control.
      #
      # @return [Boolean] Returns `true` if the model has access control functionality.
      
      def has_access_control?
        true
      end

      # Check if an actor has permission to perform an operation on an asset.
      # The *actor* requests permission *permission* on `self`.
      #
      # There is a permission request method for class objects, because some operations are performed
      # at the class level; the typical example is running a query as part of the implementation of
      # and `index` action.
      #
      # Because this method is a wrapper around {Fl::Core::Access::Checker#access_check}, it has
      # essentially the same behavior.
      #
      # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The requested permission.
      #  See {Fl::Core::Access::Helper.permission_name}.
      # @param actor [Object] The actor requesting permissions.
      # @param context [any] An arbitrary value containing the context in which to do the check.
      #
      # @return [Boolean,nil] Returns the value from a call to {Fl::Core::Access::Checker#access_check}:
      #  the boolean value `true` if access rights were granted, and `false` if access rights were denied.
      #  Under some conditions, `nil` may be returned to indicate that there was some kind of error
      #  when checking for access; a `nil` return value indicates that access rights were not granted,
      #  and it **must** be interpreted as such.

      def has_permission?(permission, actor, context = nil)
        self.access_checker.access_check(permission, actor, self, context)
      end
    end
    
    # The methods in this module are installed as instance method of the including class.
    # Note that these methods are installed by {ClassMacros#has_access_control}, so that only classes
    # that use access control implement these methods.

    module InstanceMethods
      # Set the access checker.
      # Individual instances of the base class have the option of overriding the class access checker to
      # install custom access rights management.
      # This is not a common occurrence, because it opens potential security holes, but is provided so
      # that you can shoot yourself in the foot if you desire so.
      #
      # @param checker [Fl::Core::Access::Checker] The checker to install for this instance.
      #  A `nil` value clears the access checker, which reverts back to the class access checker.

      def access_checker=(checker)
        if checker.nil?
          self.remove_instance_variable(:@_instance_access_checker)
        else
          self.instance_variable_set(:@_instance_access_checker, checker)
        end
      end

      # Get the access checker.
      # If an instance access checker has been defined, it is returned.
      # Otherwise, the method forwards the call to the class method by the same name
      # ({Fl::Core::Access::Access::ClassMethods#access_checker}).
      #
      # @return [Fl::Core::Access::Checker] Returns the value that was passed to {ClassMacros#has_access_control}.

      def access_checker()
        if self.instance_variable_defined?(:@_instance_access_checker)
          self.instance_variable_get(:@_instance_access_checker)
        else
          self.class.access_checker()
        end
      end

      # Check if an actor has permission to perform an operation on an asset.
      # The *actor* requests permission *permission* on `self`.
      # The method gets the current access checker from {#access_checker}, and triggers a call to
      # {Fl::Core::Access::Checker#access_check}.
      # Because it is a wrapper around {Fl::Core::Access::Checker#access_check}, it has
      # essentially the same behavior.
      #
      # The common case is that the class access checker is used; however, if individual instances
      # have installed their own access checker, that object is used instead.
      #
      # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The requested permission.
      #  See {Fl::Core::Access::Helper.permission_name}.
      # @param actor [Object] The actor requesting permissions.
      # @param context An arbitrary value containing the context in which to do the check.
      #
      # @return [Boolean,nil] Returns the value from a call to {Fl::Core::Access::Checker#access_check}:
      #  the boolean value `true` if access rights were granted, and `false` if access rights were denied.
      #  Under some conditions, `nil` may be returned to indicate that there was some kind of error
      #  when checking for access; a `nil` return value indicates that access rights were not granted,
      #  and it **must** be interpreted as such.

      def has_permission?(permission, actor, context = nil)
        self.access_checker.access_check(permission, actor, self, context)
      end
    end

    # Perform actions when the module is included.
    # - Injects the class macros, to make {ClassMacros#has_access_control} available. Additional class
    #   and instance methods are injected by {ClassMacros#has_access_control}.

    def self.included(base)
      base.extend ClassMacros

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end

class ActiveRecord::Base
  # Backstop class access control checker.
  # This is the default implementation, which returns `false`, for those models that have not
  # registered as having access control support.
  #
  # @return [Boolean] Returns `false`; {Fl::Core::Access::Access::ClassMethods#has_access_control?}
  #  overrides the implementation to return `true`.
  
  def self.has_access_control?
    false
  end

  # Instance asset checker.
  # Calls the class method {.has_access_control?} and returns its return value.
  #
  # @return [Boolean] Returns the return value from {.has_access_control?}.
  
  def has_access_control?
    self.class.has_access_control?
  end
end
