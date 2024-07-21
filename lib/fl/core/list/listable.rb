module Fl::Core::List
  # Extension module for use by objects that can be placed in lists.
  # This module defines the functionality for all model classes that support being added to lists.
  #
  # Note that inclusion of this module is not enough to make an object listable: the {Listable.is_listable} class
  # method must be called to turn on list functionality:
  #
  # ```
  # class MyClass < ApplicationRecord
  #   include Fl::Core::List::Listable
  #
  #   is_listable
  # end
  # ```
  #
  # We do this because {.is_listable) is configurable.
  #
  # The concern registers a number of instance methods that assume that the **listable_containers** association
  # is defined (which it is, by {.is_listable}).
  
  module Listable
    extend ActiveSupport::Concern

    # @!method is_listable(cfg = {})
    #   @!scope class
    #   Add listable behavior to a model.
    #   A listable model can be added to one or more lists, which it tracks through a `has_many`
    #   association named **listable_containers**, which is defined in the body of this method.
    #   Therefore, if a model is defined like this:
    #
    #   ```
    #   class MyListable < ActiveRecord::Base
    #     include Fl::Core::List::Listable
    #
    #     is_listable
    #   end
    #   ```
    #
    #   then instances of `MyListable` include an association named **listable_containers**.
    #
    #   @param [Hash] cfg A hash containing configuration parameters.
    #
    #   @option cfg [Symbol,String,Proc] :summary (:title) The summary method to use. This is a symbol
    #    or string containing the name of the method called by the {Listable#list_item_summary}
    #    method to get the summary for the object.
    #    It can also be a Proc that takes no arguments and returns a string.

    # @!method listable?
    #   @!scope class
    #   Check if this model is listable.
    #
    # @return [Boolean] Returns @c true if the model class is listable.

    # this comment is a hack for the yard parser
    
    class_methods do
      def is_listable(cfg = {})
        if cfg.has_key?(:summary)
          case cfg[:summary]
          when Symbol, Proc
            self.class_variable_set(:@@listable_summary_method, cfg[:summary])
          when String
            self.class_variable_set(:@@listable_summary_method, cfg[:summary].to_sym)
          else
            self.class_variable_set(:@@listable_summary_method, :title)
          end
        else
          self.class_variable_set(:@@listable_summary_method, :title)
        end

        self.instance_eval do
          def listable_summary_method
            self.class_variable_get(:@@listable_summary_method)
          end
        end
        
        # This association tracks the lists (containers) to which this listable object belongs

        has_many :listable_containers, class_name: 'Fl::Core::List::BaseItem', as: :listed_object,
      		 dependent: :destroy

        after_save :refresh_object_summaries
      end

      def listable?
        true
      end
    end
    
    # Check if this object can be placed in a list.
    # Forwards the call to the class method {.listable?}.
    #
    # @return [Boolean] Returns `true` if the object can be placed in a list.
        
    def listable?
      self.class.listable?
    end
    
    # Get the object's summary.
    # This method calls the value of the configuration option **:summary** to
    # {Fl::Core::List::Listable.is_listable} to get the object summary.
    #
    # @return [String] Returns the object summary.

    def list_item_summary()
      p = self.class.listable_summary_method
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

    # Get the lists to which this object belongs.
    # This method is a wrapper around the **listable_containers** association.
    #
    # @param [Boolean] reload If `true`, reload the **:listable_containers** association.
    #
    # @return [Array<Fl::Core::List::List>] Returns an array containing the lists to which
    #  the object belongs.

    def lists(reload = false)
      self.listable_containers.reload if reload
      self.listable_containers.map { |lo| lo.list }
    end
          
    # Add the object to a list.
    # This method first checks if `self` is already in the list, and if not it creates a
    # Fl::Core::List::BaseItem that places it in the list.
    #
    # @param list [Fl::Core::List::List] The list to which to add `self`; if `self` is already in
    #  *list*, ignore the request.
    # @param owner [Object] The owner of the Fl::Core::List::BaseItem that is potentially created;
    #  if `nil`, use the owner of *list*.
    #
    # @return [Fl::Core::List::BaseItem] If the object is added to *list*, returns the newly
    #  created instance of Fl::Core::List::BaseItem. If it is already in the list, return the current list item.
    #  If the return value is not valid, then the list item was not created, and `self` was not added to *list*.

    def add_to_list(list, owner = nil)
      li = Fl::Core::List::BaseItem.query_for_listable_in_list(self, list).first
      return li unless li.nil?
      
      nowner = (owner) ? owner : list.owner
      item = list.item_factory(:listed_object => self, :owner => nowner)
      if item.save
        self.listable_containers << item
      end
      
      return item
    end

    # Remove the object from a list.
    #
    # @param list [Fl::Core::List::List] The list from which to remove `self`; if `self` is not
    #  in *list*, ignore the request.
    #
    # @return [Boolean] Returns `true` if the object was removed, `false` otherwise.

    def remove_from_list(list)
      li = Fl::Core::List::BaseItem.query_for_listable_in_list(self, list).first
      if li.nil?
        false
      else
        self.listable_containers.delete(li)
        true
      end
    end

    # Check if the listable is in a list.
    #
    # @param list [Fl::Core::List::List] The list to which to add `self`; if `self` is already in
    #  *list*, ignore the request.
    #
    # @return [Fl::Core::List::BaseItem,nil] If `self` is in *list*, it returns the corresponding list item;
    #  otherwise, it returns `nil`.

    def in_list?(list)
      return Fl::Core::List::BaseItem.query_for_listable_in_list(self, list).first
    end
    
    private

    # Refresh the denormalized object_summary attribute in the list items for this listable.

    def refresh_object_summaries()
      Fl::Core::List::BaseItem.refresh_item_summaries(self)
    end

    # Perform actions when the module is included.

    included do
    end
  end
end

class ActiveRecord::Base
  # Backstop listable checker.
  # This is the default implementation, which returns `false`, for those models that have not
  # registered as listables.
  #
  # @return [Boolean] Returns `false`; {Fl::Core::List::Listable.is_listable} overrides
  #  the implementation to return `true`.
  
  def self.listable?
    false
  end

  # Backstop listable checker.
  # This is just a wrapper to the class method {.listable?}.
  #
  # @return [Boolean] Returns the value returned by {.listable?}.
  
  def listable?
    self.class.listable?
  end

  # Backstop list item summary extractor.
  # This is the default implementation, which returns an empty string, for those models that have not
  # registered as listables.
  #
  # @return [String] Returns an empty string; {Fl::Core::List::Listable.is_listable}
  #  overrides the implementation to return an appropriate value for the item summary.

  def list_item_summary
    ''
  end
end
