require 'fl/core/access'

module Fl::Core::Comment
  # Extension module for use by objects that need to implement comment management.
  # This module defines common functionality for all model classes that use comments; these objects are
  # accessed as the *commentable* from the comment objects.
  #
  # Note that inclusion of this module is not enough to turn on comment management: the class method
  # {Commentable.has_comments} must be called to indicate that this class
  # supports comments; for example, for Neo4j:
  #
  # ```
  #  class MyClass
  #    include Neo4j::ActiveNode
  #    include Fl::Core::Comment::Commentable
  #    include Fl::Core::Comment::Neo4j::Commentable
  #
  #    has_comments orm: :neo4j
  #  end
  # ```
  #
  # and for Active Record:
  #
  # ```
  #  class MyClass < ApplicationRecord
  #    include Fl::Core::Comment::Commentable
  #
  #    has_comments
  #  end
  # ```
  #
  # (`:activerecord` is the default ORM.)
  # The reason we do this is that the {Commentable.has_comments} method
  # is configurable, and different classes may want to customize comment management.
  #
  # The {Commentable} module defines generic code; there are also ORM-specific modules that implement
  # specialized functionality like the creation of query objects.

  module Commentable
    extend ActiveSupport::Concern
    
    # @!method has_comments(cfg = {})
    #   @!scope class
    #   Add commentable behavior to a model.
    #   This method registers the APIs used to manage comments:
    #
    #   - Adds the `comments` association to track comments; the association depends on the selected ORM.
    #   - Defines the `build_comment` method, a wrapper around the constructor for the comment class
    #     appropriate for the selected ORM. The argument to this method is a hash of parameters to pass to
    #     the comment class constructor. For example, calling `build_comment` on a commentable configured for
    #     ActiveRecord returns an instance of {Fl::Core::Comment::ActiveRecord::Comment}.
    #   - If the ORM is Neo4j, includes the module {Fl::Core::Neo4j::AssociationProxyCache}.
    #     (This is currently not implemented.)
    #   - Define the {.commentable?} method to return `true` to indicate that the class supports comments.
    #   - Optionally generate code to manage the comment count for the commentable, in the commentable's table.
    #
    #   #### Managing the comment count
    #
    #   The **:counter** property of *cfg* enables code to track the comment count for a commentable on comment
    #   creation or destruction. A value of `false` turns off the tracking code. A string or symbol is the name
    #   of an (integer) attribute in the commentable that holds the number of comments for it; for example,
    #   if the value is `:ccount`, then the code expects that the commentable has defined an attribute named
    #   `:ccount`, with integer value. Note that a value of `true` enables tracking, using the attribute
    #   `:num_comments`.
    #
    #   If tracking is enabled, {.has_comments} registers a create callback that bumps the value of the
    #   counter after a comment is created, and a destroy callback to drop the value after a comment is deleted.
    #   Note that this funcyionality is not enabled by default because it requires a support attribute (column)
    #   in the commentable, and because it has a negative (but small) impact on performance.
    #
    #   Note that this functionality is currently support on the ActiveRecord ORM only.
    #
    #   @param cfg [Hash] A hash containing configuration parameters.
    #   @option cfg [Symbol] :orm is the ORM to use. Currently, we support two ORMs: +:activerecord+
    #    for Active Record, and +:neo4j+ for the Neo4j graph database.
    #    The default value is +:activerecord+.
    #   @option cfg [Symbol, String, Proc] :summary is the summary method to use.
    #    This is a symbol or string containing the name of the method
    #    called by the #box_item_summary method to get the summary for the object.
    #    It can also be a Proc that takes no arguments and returns a string.
    #    Defaults to :title.
    #   @option cfg [Symbol,String,Boolean] :counter enables of disables tracking of the comment count in a
    #    commentable's table. See the documentation above for details.

    # @!method commentable?
    #   @!scope class
    #   Reports if the class is a convertible.
    #
    #   @return [Boolean] Returns `true` if the class has registered as a commentable.
    
    class_methods do
      def has_comments(cfg = {})
        if cfg.has_key?(:summary)
          case cfg[:summary]
          when Symbol, Proc
            @summary_method = cfg[:summary]
          else
            @summary_method = :title
          end
        else
          @summary_method = :title
        end

        orm = if cfg.has_key?(:orm)
                case cfg[:orm]
                when :activerecord, :neo4j
                  cfg[:orm]
                else
                  :activerecord
                end
              else
                :activerecord
              end

        # This association tracks the comments associated with an object.

        case orm
        when :activerecord
          has_many :comments, as: :commentable,
                   class_name: Fl::Core::Comment.object_class_name,
                   dependent: :destroy
          def build_comment(h)
            return Fl::Core::Comment::Helper.object_class.new(h)
          end

          counter = if cfg[:counter].nil? || (cfg[:counter] == false)
                      nil
                    elsif cfg[:counter] == true
                      'num_comments'
                    elsif cfg[:counter].is_a?(String)
                      cfg[:counter]
                    elsif cfg[:counter].is_a?(Symbol)
                      cfg[:counter].to_s
                    else
                      nil
                    end
          unless counter.nil?
            # Unfortunately we cannot run a sanity check that the commentable has defined the counter attribute,
            # because Rake loads the classes before running migrations, and therefore executes this code before the
            # table exists
            #raise "Internal error: has_comments expects #{self.name} to have attribute :#{counter}"

            bumper = <<EOD
def _bump_comment_count(saveit = true)
  if self.class.attribute_names.include?('#{counter}')
    if self.#{counter}.blank?
      self.#{counter} = 1
    else
      self.#{counter} = self.#{counter} + 1
    end
    if saveit
      unless self.save
        Rails.logger.warn("++++++++++ WARNING: failed to bump comment counter: \#{self.errors.messages}")
      end
    end
  else
    Rails.logger.warn("++++++++++ WARNING: #{self.name} does not define attribute #{counter}")
  end
end
EOD
            class_eval bumper

            dropper = <<EOD
def _drop_comment_count(saveit = true)
  if self.class.attribute_names.include?('#{counter}')
    if self.#{counter}.blank?
      self.#{counter} = 0
    else
      self.#{counter} = self.#{counter} - 1
    end
    self.#{counter} = 0 if self.#{counter} < 0
    if saveit
      unless self.save
        Rails.logger.warn("++++++++++ WARNING: failed to drop comment counter: \#{self.errors.messages}")
      end
    end
  else
    Rails.logger.warn("++++++++++ WARNING: #{self.name} does not define attribute #{counter}")
  end
end
EOD
            class_eval dropper
          end
        when :neo4j
          raise "Neo4j not implemented"
          #has_many :in, :comments, rel_class: :'Fl::Framework::Neo4j::Rel::Core::CommentFor', dependent: :destroy
          #include Fl::Framework::Neo4j::AssociationProxyCache
          #def build_comment(h)
          #  Fl::Framework::Comment::Neo4j::Comment.new(h)
          #end
        end
      end

      def commentable?
        true
      end

      def summary_method
        @summary_method
      end
    end
    
    # Check if this object manages comments.
    # Forwards the call to the class method {.commentable?}.
    #
    # @return [Boolean] Returns `true` if the object manages comments.
        
    def commentable?
      self.class.commentable?
    end

    # Get the object's summary.
    # This method calls the value of the configuration option :summary to {.has_comments} to get the
    # object summary.
    #
    # @return [String] Returns the object summary.

    def comment_summary()
      p = self.class.summary_method
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

    # Add a comment.
    # This method creates a new comment owned by *author* and associated with `self`.
    # If the comment is created, the association proxy cache entry for `:comments` is cleared, so that
    # the new comment is picked up (this is done for Neo4j only).
    # If the comment creation fails, any errors from the comment object are copied over to `self`,
    # prefixed by the string `comment_` (for example, a `base` error in the comment is mapped to
    # `comment_base` in the commentable).
    #
    # @param author [Object] The comment author, who will be its owner.
    # @param contents_html [String] The HTML contents of the comment.
    # @param contents_json [Hash,String] The contents of the comment, in JSON.
    #  A string value is parsed as a JSON object.
    # @param title [String] The title of the comment; if `nil`, the title is extracted from the first
    #  40 text elements of the contents.
    #
    # @return [Object, nil] Returns the new comment if it was created successfully, `nil` otherwise.

    def add_comment(author, contents_html, contents_json, title = nil)
      h = {
        author: author,
        commentable: self,
        contents_html: contents_html,
        contents_json: contents_json
      }

      h[:title] = title unless title.nil?

      c = self.class.build_comment(h)
      if c.save
        if self.respond_to?(:clear_association_proxy_cache_entry)
          clear_association_proxy_cache_entry(:comments)
        end
        c
      else
        if Rails.version >= "6.1"
          # Rails 6.1 uses a one-parameter block

          c.errors.each do |e|
            errors.add("comment.#{e.attribute}".to_sym, e.message)
          end
        else
          c.errors.each do |ek, ev|
            self.errors.add("comment.#{ek}", ev)
          end
        end
        nil
      end
    end

    # Perform actions when the module is included.

    included do
    end
  end
end

class ActiveRecord::Base
  # Backstop class commentable checker.
  # This is the default implementation, which returns `false`, for those models that have not
  # registered as having comments.
  #
  # @return [Boolean] Returns `false`; {Fl::Core::Comment::Commentable.commentable?}
  #  overrides the implementation to return `true`.
  
  def self.commentable?
    false
  end

  # Instance commentable checker.
  # Calls the class method {.commentable?} and returns its return value.
  #
  # @return [Boolean] Returns the return value from {.commentable?}.
  
  def commentable?
    self.class.commentable?
  end
end
