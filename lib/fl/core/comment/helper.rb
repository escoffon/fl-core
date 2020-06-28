require 'fl/core/parameters_helper'

module Fl::Core::Comment
  # Helper module for comments.
  # This module defines utilities for comment management.

  module Helper
    # Convert a commentable parameter to an object.
    # This is a wrapper around {Fl::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    # The method adds a type check for the commentable to require that the object has included the
    # {Commentable} module.
    #
    # @param p The parameter value. See {Fl::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an instance of a commentable class, or `nil` if no object was found.
    #
    # @raise [Fl::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.commentable_from_parameter(p, key = :commentable)
      x = Proc.new { |obj| obj.class.include?(Fl::Comment::Commentable) }
      Fl::Core::ParametersHelper.object_from_parameter(p, key, x)
    end

    # Convert an author parameter to an object.
    # This is a wrapper around {Fl::Core::ParametersHelper.object_from_parameter}; see that
    # documentation for details on the arguments.
    #
    # @param p The parameter value. See {Fl::Core::ParametersHelper.object_from_parameter}.
    # @param key [Symbol] The key to look up, if *p* is a Hash.
    #
    # @return Returns an object holding the author, or `nil` if no object was found. Note that no type
    #  checking is done.
    #
    # @raise [Fl::Core::ParametersHelper::ConversionError] Thrown by the helper method.

    def self.author_from_parameter(p, key = :author)
      Fl::Core::ParametersHelper.object_from_parameter(p, key)
    end

    # Include hook.
    # Adds to the including class the instance methods +commentable_from_parameter+ and
    # +author_from_parameter+ that forward the calls to
    # {Fl::Framework::Comment::Helper.commentable_from_parameter} and 
    # {Fl::Framework::Comment::Helper.author_from_parameter}, respectively.

    def self.included(base)
      base.class_eval do
        def commentable_from_parameter(p, key = nil)
          Fl::Core::Comment::Helper.commentable_from_parameter(p, key)
        end

        def author_from_parameter(p, key = nil)
          Fl::Core::Comment::Helper.author_from_parameter(p, key)
        end
      end
    end
  end
end
