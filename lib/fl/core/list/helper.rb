module Fl::Core::List
  # Helpers for the list module.

  module Helper
    # Enable listable support for a class.
    # Use this method to convert an existing class into a listable:
    #
    # ```
    # class TheClass < ActiverRecord::Base
    #   # class definition
    # end
    #
    # Fl::Core::List::Helper.make_listable(TheClass, summary: :my_summary_method)
    # ```
    # See the documentation for {Listable::ClassMethods#is_listable}.
    # If the class is already marked as listable, the operation is skipped.
    #
    # @param klass [Class] The class object where listable behavior is enabled.
    # @param cfg [Hash] A hash containing configuration parameters. See the documentation for
    #  {Listable::ClassMethods#is_listable}.

    def self.make_listable(klass, *cfg)
      unless klass.listable?
        klass.send(:include, Fl::Core::List::Listable)
        klass.send(:is_listable, *cfg)
      end
    end

    # Convert a listable parameter to an object.
    # This is a wrapper around {Fl::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param p The parameter value. See {Fl::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an object holding the listable, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.listable_from_parameter(p, key = :listable)
      Fl::Core::ParametersHelper.object_from_parameter(p, key)
    end

    # Convert a list parameter to an object.
    # This is a wrapper around {Fl::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param l The parameter value. See {Fl::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *l* is a Hash.
    #
    # @return Returns a list object, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.list_from_parameter(l, key = :list)
      Fl::Core::ParametersHelper.object_from_parameter(l, key)
    end

    # Traverse the container hierarchy for a listable.
    # This method traverses the list of containers (as returned by {Fl::Core::List::Listable#list} depth first,
    # yielding to *block* for each container.
    # The traversal terminates at containers whose {Fl::Core::List::Listable#list} value is an empty array.
    #
    # @param listable The *listable* is an object that responds to **:listable?** and whose return value is
    #  `true`.
    # @param context [any] A context object to pass to the block; this is often a Hash.
    # @param block [block] A block which is executed for each traversed node.
    #
    # @yieldparam listable The value of *listable*.
    # @yieldparam list [Fl::Core::List::Base] The container list.
    # @yieldparam level [Integer] The traversal depth of the node; starts at 0 and increases by 1 with each call
    #  into parent elements.
    # @yieldparam context [any] The value of *context*.
    #
    # @yieldreturn [Boolean,any] The block returns `false` to terminate the traversal early. With any other return
    #  value, traversal continues.
    #
    # @return [Boolean,nil] If the traversal completes, the method returns `true`; if it exits early due to the value
    #  of *block*, it returns `false`; with errors or invalid arguments, it returns `nil`.

    def self.traverse_containers(listable, context = { }, &block)
      return nil if !listable.respond_to?(:listable?) && !listable.listable?
      return nil if block.nil?

      level = 0
      listable.lists.each do |l|
        return false if !_traverse_containers(listable, l, level, context, &block)
      end

      return true
    end

    private

    def self._traverse_containers(listable, list, level, context, &block)
      # first, the list itself

      return false if !block.call(listable, list, level, context)

      # now the containers

      level += 1
      list.lists.each do |l|
        return false if !_traverse_containers(listable, l, level, context, &block)
      end

      return true
    end

    # Perform actions when the module is included.

    def self.included(base)
      base.class_eval do
        # include InstanceMethods
      end
    end
  end
end
