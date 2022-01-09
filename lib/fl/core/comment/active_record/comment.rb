require 'fl/core/application_record'
require 'fl/core/comment/common'

module Fl::Core::Comment::ActiveRecord
  # Implementation of the comment object for an ActiveRecord database.
  # It will need the migration `create_fl_core_comments`.
  #
  # #### Single Table Inheritance
  #
  # The class defines the `type` attribute (column) to support Single Table Inheritance (STI).
  # The main reason for this is to provide better support for custom comment class names, as outlined in the
  # documentation for the `fl:core:comments:install` generator: when the comment subsystem is installed in a Rails
  # application, a simple comment class is installed as an empty subclass of `Fl::Core::Comment::ActiveRecord::Comment`.
  # This gives the application a more convenient (and customizable) name for the comment class, and an anchor for
  # extension features. STI is not strictly speaking needed, but it does provide a more predictable API than if
  # the the custom class was generated without it. (It also bakes in STI, so that the application does not need
  # to add it locally.)
  #
  # #### Attributes
  # This class defines the following attributes:
  #
  # - **is_visible** is a boolean flag to indicate if the comment is visible or not.
  # - **title** is a string containing a title for the comment.
  # - **contents_html** is a string containing the HTML representation of the contents of the comment.
  # - **contents_json** is a hash containing the JSON representation of the contents of the comment.
  # - **created_at** is a Time containing the creation time.
  # - **updated_at** is a Time containing the modification time.
  #
  # #### Associations
  # The class defines a number of associations:
  #
  # - {#commentable} is the object associated with this comment (the *commentable* object).
  # - {#author} is the entity (typically a user) that created the comment.
  # - {#comments} is the list of comments associated with this comment (and therefore, the comment's
  #   subcomments that make up the conversation about the comment).
  #   This association is created because comments are declared to be commentables.
  #
  # #### Lifecycle hooks
  #
  # - The {#commentable}'s **:updated_at** timestamp is set to the current time when the comment is created,
  #   updated, or destroyed.
  # - The {#commentable}'s comment count field is increased or decreased when the comment is created or destroyed,
  #   respectively.
  
  class Comment < Fl::Core::ApplicationRecord
    include Fl::Core::ModelHash
    include Fl::Core::Access::Access
    include Fl::Core::Comment::Commentable
    include Fl::Core::Comment::ActiveRecord::Commentable
    include Fl::Core::Comment::Common

    self.table_name = 'fl_core_comments'

    has_access_control Fl::Core::Comment::Checker.new

    # Return the default `to_hash` options for a commentable.
    # The comment class could potentially use multiple commentable classes: for example, since comments
    # are commentables, they can be associated with comment instances as well as others.
    #
    # This method supports the ability to define the `to_hash` parameters to use with a **:commentable**
    # key; users of the framework can override this method to add support for user-specific commentable
    # classes.
    #
    # The default implementation returns `{ verbosity: :minimal }`.
    #
    # @param commentable [Object] The commentable to hash.
    #
    # @return [Hash] Returns a hash containing default options for *commentable*; note that this value can be
    #  overridden in a `to_hash` by passing appropriate arguments.

    def self.default_commentable_to_hash_options(commentable)
      return { verbosity: :minimal }
    end

    # Return the default `to_hash` options for a commentable.
    # This is wrapper that forwards the call to the class object; see {.default_commentable_to_hash_options}.
    #
    # @param commentable [Object] The commentable to hash.
    #
    # @return [Hash] Returns a hash containing default options for *commentable*; note that this value can be
    #  overridden in a `to_hash` by passing appropriate arguments.

    def default_commentable_to_hash_options(commentable)
      return self.class.default_commentable_to_hash_options(commentable)
    end
    
    # @!attribute [rw] is_visible
    # The visibility flag; defaults to `true`.
    # @return [Boolean] a boolean value to indicate if the comment is visible.

    # @!attribute [rw] title
    # The comment title; typically generated from the first (40) character of the contents.
    # @return [String] Returns the comment title.

    # @!attribute [rw] contents_html
    # The HTML representation of the comment contents.
    # @return [String] Returns the comment contents.

    # The contents, as a JSON object.
    # The structure of the object is left to clients of the subsystem.
    # For example, it could be operations in [Quill Delta](https://quilljs.com/docs/delta) format, or
    # [Prosemirror](https://prosemirror.net/) content.
    # Since this is also the content associated with the comment, it should be consistent with the contents
    # of {#contents_html}.
    # @return [Hash] the contents, as would be returned by a call to the `getContents` Quill API.

    serialize :contents_json, JSON

    # @!attribute [rw] created_at
    # The time when the comment was created.
    # @return [DateTime] Returns the creation time of the comment.

    # @!attribute [rw] updated_at
    # The time when the comment was updated.
    # @return [DateTime] Returns the modification time of the comment.

    # @!attribute [r] commentable
    # The object to which the comment is attached.
    # @return [Association] Returns the association for the commentable. The corresponding object is the object
    #  to which the comment is attached. This object is expected
    #  to have included the {Fl::Core::Comment::Commentable} module and have registered via
    #  {Fl::Core::Comment::Commentable#has_comments}.

    belongs_to :commentable, polymorphic: true

    # @!visibility private
    def commentable_fingerprint=(fp)
    end

    # @!attribute [r] author
    # The entity that created the comment, and therefore owns it.
    # @return [Object] Returns the object that created the comment.

    belongs_to :author, polymorphic: true

    # @!visibility private
    def author_fingerprint=(fp)
    end

    # manage comment counts in the commentable
    
    after_create :_after_create_check
    after_destroy :_after_destroy_check
    before_save :_check_visibility
    after_save :_after_save_check

    # has_comments defines the :comments association

    # @!attribute [rw] comments
    # The comments for this comment.
    # It is possible to comment on a comment.
    # @return [ActiveRecord::Associations::CollectionProxy] Returns an ActiveRecord association listing
    #  comments.

    has_comments counter: :num_comments

    before_create :populate_fingerprints

    # @!visibility private
    QUERY_FILTERS_CONFIG = {
      filters: {
        commentables: {
          type: :polymorphic_references,
          field: 'commentable_fingerprint',
          convert: :fingerprint
        },

        authors: {
          type: :polymorphic_references,
          field: 'author_fingerprint',
          convert: :fingerprint
        },

        visibility: {
          type: :custom,
          field: 'is_visible',
          convert: :custom,
          generator: Proc.new do |g, n, d, v|
            # Note that this generator is not called if :visibility is not defined, which means that if the
            # filter is not defined all records are returned.
            # If the value is nil, we don't generate a clause, which results in all records being returned
            # Otherwise, :visible and :hidden select the corresponding record types, and anything else generates
            # no clause

            dflag = v.nil? ? :both : v.to_sym
            if dflag == :visible
              p = g.allocate_parameter(true)
              "(is_visible = :#{p})"
            elsif dflag == :hidden
              p = g.allocate_parameter(false)
              "(is_visible = :#{p})"
            else
              nil
            end
          end
        },

        created: {
          type: :timestamp,
          field: 'created_at',
          convert: :timestamp
        },

        updated: {
          type: :timestamp,
          field: 'updated_at',
          convert: :timestamp
        }
      }
    }
    
    # Initializer.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    # @option attrs [Object, Hash, String] :author The comment author. The value is resolved via a call
    #  to {Fl::Core::Comment::Helper.author_from_parameter}.
    # @option attrs [Object, Hash, String] :commentable The associated commentable. The value is resolved via
    #  a call to {Fl::Core::Comment::Helper.commentable_from_parameter}.
    # @option attrs [String] :contents The comment contents.
    # @option attrs [Hash,String] :contents_delta The comment contents, in Delta format. A string value is
    #  converted to a Hash using the JSON parser.
    # @option attrs [String] :title The comment title; if not given, the first 40 characters of the content
    #  are used.

    def initialize(attrs = {})
      super(attrs)
    end

    # Set the commentable.
    # If the object is persisted, the call is ignored: once set, the commentable cannot be changed.
    # Otherwise, convert *c* to an object and set it; if the conversion fails, place an error message under
    # the **:commentable** key.
    #
    # @param c [ActiveRecord::Base,String,GlobalID] A commentable object, a string containing an object
    #  fingerprint or a GlobalID, or a GlobalID object.
    
    def commentable=(c)
      begin
        super(Fl::Core::Comment::Helper.commentable_from_parameter(c)) unless self.persisted?
        self.errors.delete(:commentable)
      rescue => exc
        if Rails.version >= "6.1"
          self.errors.add(:commentable, exc.message)
        else
          self.errors[:commentable] << exc.message
        end
      end
    end

    # Set the author.
    # If the object is persisted, the call is ignored: once set, the author cannot be changed.
    # Otherwise, convert *a* to an object and set it; if the conversion fails, place an error message under
    # the **:author** key.
    #
    # @param a [ActiveRecord::Base,String,GlobalID] A commentable object, a string containing an object
    #  fingerprint or a GlobalID, or a GlobalID object.

    def author=(a)
      begin
        super(Fl::Core::Comment::Helper.author_from_parameter(a)) unless self.persisted?
        self.errors.delete(:author)
      rescue => exc
        if Rails.version >= "6.1"
          self.errors.add(:author, exc.message)
        else
          self.errors[:author] << exc.message
        end
      end
    end

    # Set the JSON representation of the contents.
    # If *cd* is a string, convert it to a JSON object before setting it. If the JSON conversion fails, place
    # an error message under the **:contents_json** key.
    #
    # @param cd [String,Hash] The Delta contents.

    def contents_json=(cd)
      begin
        if cd.is_a?(String)
          super(JSON.parse(cd))
        else
          super(cd)
        end
        self.errors.delete(:contents_json)
      rescue => exc
        if Rails.version >= "6.1"
          self.errors.add(:contents_json, exc.message)
        else
          self.errors[:contents_json] << exc.message
        end
      end
    end
    
    # Build a query to fetch comments.
    #
    # The **:filters** option contains a description of clauses to restrict the result set based on one or more
    # conditions. It is meant to be parsed by {Fl::Core::Query::Filter#generate} to construct a set of WHERE clauses
    # and associated bind parameters. The following filters are supported:
    #
    # - **:commentables** is a **:polymorphic_references** filter that limits the returned values to those comments
    #   whose {#commentable} appears in the **:only** list, or does not appear in the **:except** list.
    #   The elements in the arrays are: instances of {ActiveRecord::Base}; object fingerprints; or GlobalIDs.
    # - **:authors** is a **:polymorphic_references** filter that limits the returned values to those comments
    #   whose {#author} appears in the **:only** list, or does not appear in the **:except** list.
    #   The elements in the arrays are: instances of {ActiveRecord::Base}; object fingerprints; or GlobalIDs.
    # - **:visibility** defines how to filter based on the {#is_visible} attribute.
    #   A value of `:visible` or `'visible'` selects records where {#is_visible} is `true`; a value of `:hidden`
    #   or `'hidden'` those where {#is_visible} is `false`; and any other value (`:both` or `nil` is a good candidate)
    #   returns both.
    #   If the option is not present, no filter is triggered, so that all records are returned by default.
    # - **:created** is a **:timestamp** filter type that selects based on the **:created_at** column.
    # - **:updated** is a **:timestamp** filter type that selects based on the **:updated_at** column.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #
    # @option opts [Hash] :filters A hash containing filter specifications; see the section on filters, above.
    # @option opts [Integer] :offset Sets the number of records to skip before returning;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to 0 (start at the beginning).
    # @option opts [Integer] :limit The maximum number of comments to return;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to all comments.
    # @option opts [String] :order A string containing the <tt>ORDER BY</tt> clause for the comments;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to <tt>updated_at DESC</tt>, so that the comments are ordered by modification time, 
    #  with the most recent one listed first.
    # @option opts [Symbol, Array<Symbol>, Hash] :includes An array of symbols (or a single symbol),
    #  or a hash, to pass to the +includes+ method
    #  of the relation; see the guide on the ActiveRecord query interface about this method.
    #  The value is normalized via a call to {Fl::Core::Query::QueryHelper.normalize_includes}.
    #  The default value is `[ :commentable, :author ]`; if you know that the commentable and author contain
    #  an attachment attribute like `avatar`, a good value for this option is
    #  `[ { commentable: [ :avatar] }, { author: [ :avatar ] } ]`.
    # @option opts [String,Symbol,Array<String,Symbol>] :attachments The names of properties in **:includes**
    #  that contain ActiveStorage attachments; these properties are converted to a blob association by
    #  {#normalize_includes}. A scalar value is converted to a one element array.
    #  Defaults to `[ :avatar ]`.
    #
    # Note that *:limit*, *:offset*, *:order*, and *:includes* are convenience options, since they can be
    # added later by making calls to +limit+, +offset+, +order+, and +includes+ respectively, on the
    # return value. But there situations where the return type is hidden inside an API wrapper, and
    # the only way to trigger these calls is through the configuration options.
    #
    # @return [ActiveRecord::Relation] Returns an ActiveRecord relation mapping to a query in the database.
    #
    # @example Get the last 10 comments from a given commentable (showing equivalent calls)
    #  c = get_commentable_object()
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(filters: {
    #        commentables: { only: c }
    #      }, limit: 10)
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(filters: {
    #        commentables: { only: c.fingerprint }
    #      }).limit(10)
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(filters: {
    #        commentables: { only: c.to_global_id.to_s }
    #      }, order: nil).order('updated_at DESC').limit(10)
    #
    # @example Get the first 10 comments on a commentable from a given user (showing equivalent calls)
    #  c = get_commentable_object()
    #  u = get_user()
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(filters: {
    #        commentables: { only: c },
    #        authors: { only: u }
    #      }, order: 'created_at ASC, limit: 10)
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(filters: {
    #        commentables: { only: c },
    #        authors: { only: u }
    #      }, order: nil).order('created_at ASC').limit(10)
    #
    # @example Get all comments on a commentable not from a given user
    #  c = get_commentable_object()
    #  u = get_user()
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(filters{
    #        commentables: { only: c.to_global_id },
    #        authors: { except: u }
    #      })
    #
    # @example Get all comments from a given user that were created less than ten days ago
    #  u = get_user()
    #  t = Time.new
    #  t -= 10.days
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(filters: {
    #        authors: { only: u.to_global_id.to_s },
    #        created: { after: t }
    #      })

    def self.build_query(opts = {})
      q = self

      q = Fl::Core::Query::QueryHelper.add_includes(q, opts[:includes], [ :commentable, :author ], opts[:attachments])
      q = Fl::Core::Query::QueryHelper.add_filters(q, opts[:filters], QUERY_FILTERS_CONFIG)
      q = Fl::Core::Query::QueryHelper.add_order_clause(q, opts)
      q = Fl::Core::Query::QueryHelper.add_offset_clause(q, opts)
      q = Fl::Core::Query::QueryHelper.add_limit_clause(q, opts)

      return q
    end

    private

    def populate_fingerprints()
      write_attribute(:author_fingerprint, self.author.fingerprint) if self.author
      write_attribute(:commentable_fingerprint, self.commentable.fingerprint) if self.commentable
    end

    def _after_create_check()
      if self.is_visible && self.commentable.respond_to?('_bump_comment_count')
        self.commentable.send('_bump_comment_count', true)
      end
    end

    def _after_destroy_check()
      if self.is_visible && self.commentable.respond_to?('_drop_comment_count')
        self.commentable.send('_drop_comment_count', true)
      end
    end

    def _after_save_check()
      if saved_changes?
        sh = saved_changes
        if sh.has_key?('is_visible')
          # if the initial value was nil, then the comment was just created, and we do not bump/drop; if we do,
          # we end up with a double call, since after_save is called on a create

          unless sh['is_visible'][0].nil?
            if sh['is_visible'][1]
              if self.commentable.respond_to?('_bump_comment_count')
                self.commentable.send('_bump_comment_count', false)
              end
            else
              if self.commentable.respond_to?('_drop_comment_count')
                self.commentable.send('_drop_comment_count', false)
              end
            end
          end
        else
          self.commentable.updated_at = Time.new
        end
        self.commentable.save
      end
    end

    def _check_visibility()
      self.is_visible = true if self.is_visible.nil?
    end
  end
end
