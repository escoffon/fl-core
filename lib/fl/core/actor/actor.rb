module Fl::Core::Actor
  # Extension module that adds support for actor behavior.
  # An actor is an entity that performs operations; the typical example is a user, but software agents
  # could also be actors.

  module Actor
    # Class macros for actor objects.
    # {ClassMacros#is_actor} is used to indicate that instances of the class include actor functionality.
    
    module ClassMacros
      # Add actor behavior to a model.
      # An actor model is used to request permission grants and to define the entity that performs an
      # operation. It can be added to one or more groups, which it tracks through a `has_many`
      # association named **actor_containers**, which is defined in the body of this method.
      # Therefore, if a model is defined like this:
      #
      # ```
      #   class MyActor < ActiveRecord::Base
      #     include Fl::Core::Actor::Actor
      #
      #     is_actor
      #   end
      # ```
      #
      # then instances of `MyActor` include an association named **actor_containers** (and a number of methods).
      #
      # @param [Hash] cfg A hash containing configuration parameters.
      # @option cfg [Symbol,String,Proc] :title (:name) The "title" method is used to populate the
      #  **:title** attribute of a group member object if one is not explicitly given.
      #  It is customizable to support a wide range of objects that register as actors.
      #  The value is a symbol or string containing the name of the method called by the
      #  {Fl::Core::Actor::Actor::InstanceMethods#group_member_title}
      #  method to get the title for the group member.
      #  It can also be a Proc that takes no arguments and returns a string.

      def is_actor(cfg = {})
        if cfg.has_key?(:title)
          case cfg[:title]
          when Symbol, Proc
            self.class_variable_set(:@@_actor_title_method, cfg[:title])
          when String
            self.class_variable_set(:@@_actor_title_method, cfg[:title].to_sym)
          else
            self.class_variable_set(:@@_actor_title_method, :name)
          end
        else
          self.class_variable_set(:@@_actor_title_method, :name)
        end

        self.instance_eval do
          def actor_title_method
            self.class_variable_get(:@@_actor_title_method)
          end
        end

        # This association tracks the groups to which this actor belongs

        has_many :actor_containers, :class_name => 'Fl::Core::Actor::GroupMember', :as => :actor,
      		:dependent => :destroy

        extend Fl::Core::Actor::Actor::ClassMethods
        include Fl::Core::Actor::Actor::InstanceMethods
      end
    end

    # Class methods for actor objects.
    # These methods are injected into the class by {ClassMacros#is_actor} and implement functionality
    # to manage actor behavior.
    
    module ClassMethods
      # Check if this class supports the actor functionality.
      #
      # @return [Boolean] Returns @c true if the class is an actor.
      
      def is_actor?
        true
      end
    end
    
    # Instance methods for actor objects.
    # These methods are injected into the class by {ClassMacros#is_actor} and implement functionality
    # to manage actor behavior.
    
    module InstanceMethods
      # Get the actor's summary.
      # This method calls the value of the configuration option **:title** to
      # {Fl::Core::Actor::Actor::InstanceMethods#is_actor} to get the group member title.
      #
      # @return [String] Returns the group member title to use.

      def group_member_title()
        p = self.class.actor_title_method
        case p
        when Proc
          p.call()
        when Symbol
          self.send(p)
        when String
          self.send(p.to_sym)
        else
          ''
        end
      end

      # Get the groups to which this object belongs.
      # This method is a wrapper around the **actor_containers** assocation.
      #
      # @param [Boolean] reload If `true`, reload the **actor_containers** association.
      #
      # @return [Array<Fl::Core::Actor::Group>] Returns an array containing the groups to which
      #  the object belongs.

      def groups(reload = false)
        self.actor_containers.reload if reload
        self.actor_containers.map { |gm| gm.group }
      end
          
      # Add the object to a group.
      # This method first checks if the object is already in the group, and if not it creates a
      # Fl::Core::Actor::GroupMember that places it in the group.
      #
      # @param group [Fl::Core::Actor::Group] The group to which to add `self`; if `self` is already in
      #  *group*, ignore the request.
      #
      # @return [Fl::Core::Actor::GroupMember] If the object is added to *group*, returns the newly
      #  created instance of Fl::Core::Actor::GroupMember. Otherwise, it returns the original
      #  group member object.

      def add_to_group(group)
        gm = Fl::Core::Actor::GroupMember.query_for_actor_in_group(self, group).first
        if gm.nil?
          gm = self.actor_containers.create(:group => group, :actor => self)
        end

        gm
      end

      # Remove the object from a group.
      #
      # @param group [Fl::Core::Actor::Group] The group from which to remove `self`; if `self` is not
      #  in *list*, ignore the request.
      #
      # @return [Boolean] Returns `true` if the object was removed, `false` otherwise.

      def remove_from_group(group)
        gm = Fl::Core::Actor::GroupMember.query_for_actor_in_group(self, group).first
        return false if gm.nil?

        self.actor_containers.delete(gm)
        true
      end
    end

    # Perform actions when the module is included.
    #
    # - Injects the class macros in {ClassMacros}, to make {ClassMacros#is_actor} available.
    #   Additional class and instance methods (in {ClassMethods} and {InstanceMethods}, respectively)
    #   are injected by {ClassMacros#is_actor}.

    def self.included(base)
      base.extend ClassMacros

      base.instance_eval do
      end

      base.class_eval do
        # include InstanceMethods
      end
    end
  end
end

class ActiveRecord::Base
  # Backstop actor checker.
  # This is the default implementation, which returns `false`, for those models that have not
  # registered as actors.
  #
  # @return [Boolean] Returns `false`; {Fl::Core::Actor::Actor::ClassMacros#is_actor} overrides
  #  the implementation to return `true`.
  
  def self.is_actor?
    false
  end

  # Backstop actor checker.
  # This is just a wrapper to the class method {.is_actor?}.
  #
  # @return [Boolean] Returns the value returned by {.is_actor?}.
  
  def is_actor?
    self.class.is_actor?
  end
end
