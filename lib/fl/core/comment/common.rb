require 'fl/core/comment/helper'
require 'fl/core/comment/commentable'

module Fl::Core::Comment
  # Mixin module to load common comment functionality.
  # This module defines functionality shared by comment implementations:
  #
  # ```
  #  module Fl::Core::Comment::ActiveRecord
  #    class Comment < ApplicationRecord
  #      include Fl::Core::Comment::Common
  #
  #      # ActiveRecord-specific code ...
  #    end
  #  end
  # ```

  module Common
    extend ActiveSupport::Concern

    protected

    # @!visibility private
    TITLE_LENGTH = 40

    # Set up the comment state before validation.
    # This method populates the **:title** attribute, if necessary, from the contents.

    def _before_validation_title_checks
      populate_title_if_needed(:contents, TITLE_LENGTH)
    end

    # Set up the comment state before saving.
    # This method populates the **:title** attribute, if necessary, from the contents.

    def _before_save_title_checks
      populate_title_if_needed(:contents, TITLE_LENGTH)
    end

    # @!visibility private
    DEFAULT_HASH_KEYS = [ :commentable, :author, :title, :contents, :contents_delta ]

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity == :minimal) || (verbosity == :standard)
        {
          :include => DEFAULT_HASH_KEYS
        }
      elsif (verbosity == :verbose) || (verbosity == :complete)
        {
          :include => DEFAULT_HASH_KEYS | [ ]
        }
      else
        {}
      end
    end

    # Return the default list of operations for which to check permissions.
    #
    # @return [Array<Symbol>] Returns an array of Symbol values that list the operations for which
    #  to obtain permissions.

    def to_hash_operations_list
      [ Fl::Core::Access::Permission::Read::NAME,
        Fl::Core::Access::Permission::Write::NAME,
        Fl::Core::Access::Permission::Delete::NAME,
        Fl::Core::Access::Permission::IndexComments::NAME,
        Fl::Core::Access::Permission::CreateComments::NAME
      ]
    end

    # Build a Hash representation of the comment.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param keys [Array<Symbol>] The keys to place in the hash.
    # @param opts [Hash] Options for the method; none are used by this method.
    #
    # @return [Hash] Returns a Hash containing the comment representation.
    #
    # - *:commentable* A Hash containing the two keys *:id* and *:type*, respectively the id and class name
    #   of the commentable object for which the comment was created.
    # - *:author* Information about the author; a Hash containing these keys (if supported):
    #   - *:id* The id.
    #   - *:username* The login name.
    #   - *:full_name* The full name.
    #   - *:avatar* A hash containing the URLs to the owner's avatar; the hash contains the keys *:list*,
    #     *:thumb*, *:medium*, *:large*, and *:xlarge*.
    # - *:created_at* When created, as a UNIX timestamp.
    # - *:updated_at* When last updated, as a UNIX timestamp.
    # - *:permissions* An array containing permissions on this comment.
    # - *:title* The comment title.
    # - *:contents* The contents of the comment.
    # - *:contents_delta* The contents of the comment.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}
      c = self.commentable
      u = self.author

      rv = {}
      keys.each do |k|
        case k
        when :commentable
          rv[k] = c.to_hash(actor, verbosity: :id)
        when :author
          author_opts = to_hash_opts_with_defaults(to_hash_opts[:author], {
                                                     verbosity: :id,
                                                     include: [ :username, :full_name, :avatar ]
                                                   })
          rv[k] = u.to_hash(actor, author_opts)
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    public
  
    # Include hook.
    # This method performs the following operations:
    #
    # - In the context of the comment class, includes the modules
    #   {Fl::Core::AttributeFilters}, {Fl::Core::TitleManagement}, {Fl::Core::ModelHash},
    #   {Fl::Core::Comment::Helper}, and {Fl::Core::Comment::Commentable}.
    # - Registers attribute filters for **:title** and **:contents+** the title is converted to text only,
    #   and contents are stripped of dangerous HTML.
    # - Registers a `before_validation` callback to set up the title for validation;
    #   see {._before_validation_title_checks}.
    # - Registers a `before_save` callback to set up the title for saving; see {._before_save_title_checks}.
    # - Adds validation rules:
    #   - *:commentable*, *:author*, and *:contents* must be present.
    #   - Minimum content length for *:contents* is 1.
    #   - Maximum content length for *:title* is 100.
    #   - Validate with {PermissionValidator}

    included do
      include Fl::Core::AttributeFilters
      include Fl::Core::TitleManagement
      include Fl::Core::ModelHash
      include Fl::Core::Comment::Helper
      include Fl::Core::Comment::Commentable

      # Filtered attributes

      filtered_attribute :title, [ const_get(:FILTER_HTML_STRIP_DANGEROUS_ELEMENTS),
                                   const_get(:FILTER_HTML_TEXT_ONLY) ]
      filtered_attribute :contents, const_get(:FILTER_HTML_STRIP_DANGEROUS_ELEMENTS)

      # Validation

      validates_presence_of :commentable, :author, :contents
      validates_length_of :contents, :minimum => 1
      validates_length_of :title, :maximum => 100

      # Hooks
    
      before_validation :_before_validation_title_checks
      before_save :_before_save_title_checks
    end
  end
end