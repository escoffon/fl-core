module Fl::Core::Actor
  # Helpers for the actor module.
  # Use it via `include`; the methods in {ClassMethods} are injected as class methods of the including
  # class.
  #
  # Alternatively, you can use it as a namespace for helper methods.

  module Helper
    # Enable actor support for a class.
    # Use this method to add actor support to an existing class:
    #
    # ```
    # class TheClass < ActiverRecord::Base
    #   # class definition
    # end
    #
    # Fl::Core::Actor::Helper.make_actor(TheClass)
    # ```
    # See the documentation for {Actor::ClassMacros#is_actor}.
    # If the class is already marked as an actor, the operation is skipped.
    #
    # This method is used to inject actor behavior into a class over which you may not have control (for example,
    # from another gem).
    #
    # @param klass [Class] The class object where actor behavior is enabled.
    # @param cfg [Hash] A hash containing configuration parameters. See the documentation for
    #  {Actor::ClassMacros#is_actor}.

    def self.make_actor(klass, *cfg)
      unless klass.actor?
        klass.send(:include, Fl::Core::Actor::Actor)
        klass.send(:is_actor, *cfg)
      end
    end

    # Class methods.

    module ClassMethods
    end
    
    # Convert an actor parameter to an object.
    # This is a wrapper around {Fl::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param p The parameter value. See {Fl::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an object holding the actor, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.actor_from_parameter(p, key = :actor)
      Fl::Core::ParametersHelper.object_from_parameter(p, key)
    end

    # Convert a group parameter to an object.
    # This is a wrapper around {Fl::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param p The parameter value. See {Fl::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an object holding the group, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.group_from_parameter(p, key = :group)
      Fl::Core::ParametersHelper.object_from_parameter(p, key)
    end

    # Perform actions when the module is included.
    #
    # - Injects the methods in {ClassMethods} as class methods.
    # - Adds to the including class the instance methods `actor_from_parameter`
    #   and `group_from_parameter` that forward the calls to {.owner_from_parameter}
    #   and {.group_from_parameter}, respectively.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
        # include InstanceMethods

        def actor_from_parameter(p, key = nil)
          Fl::Core::Actor::Helper.actor_from_parameter(p, key)
        end

        def group_from_parameter(p, key = nil)
          Fl::Core::Actor::Helper.group_from_parameter(p, key)
        end
      end
    end
  end
end
