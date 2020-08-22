require 'fl/core/application_record'
require 'fl/core/comment/common'

module Fl::Core::Comment::ActiveRecord
  # Implementation of the comment object for an ActiveRecord database.
  # It will need the migration `create_fl_core_comments`.
  #
  # #### Attributes
  # This class defines the following attributes:
  #
  # - **title** is a string containing a title for the comment.
  # - **contents** is a string containing the HTML representation of the contents of the comment.
  # - **contents_delta** is a hash containing the Delta representation of the contents of the comment.
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
    extend Fl::Core::Query

    self.table_name = 'fl_core_comments'

    has_access_control Fl::Core::Comment::Checker.new

    # @!attribute [rw] title
    # The comment title; typically generated from the first (40) character of the contents.
    # @return [String] Returns the comment title.

    # @!attribute [rw] contents
    # The comment contents.
    # @return [String] Returns the comment contents.

    # The contents, as a hash of operations in [Quill Delta](https://quilljs.com/docs/delta) format; since this is
    # also the content associated with the comment, it should be consistent with the contents of {#contents}.
    # @return [Hash] the contents, as would be returned by a call to the `getContents` Quill API.

    serialize :contents_delta, JSON

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
    
    after_create :_bump_comment_count_callback
    after_destroy :_drop_comment_count_callback
    after_destroy :_update_commentable_timestamp
    after_save :_update_commentable_timestamp

    # has_comments defines the :comments association

    # @!attribute [rw] comments
    # The comments for this comment.
    # It is possible to comment on a comment.
    # @return [ActiveRecord::Associations::CollectionProxy] Returns an ActiveRecord association listing
    #  comments.

    has_comments counter: :num_comments

    before_create :populate_fingerprints
    
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
        self.errors[:commentable] << exc.message
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
        self.errors[:author] << exc.message
      end
    end

    # Set the Delta representation of the contents.
    # If *cd* is a string, convert it to a JSON object before setting it. If the JSON conversion fails, place
    # an error message under the **:contents_delta** key.
    #
    # @param cd [String,Hash] The Delta contents.

    def contents_delta=(cd)
      begin
        if cd.is_a?(String)
          super(JSON.parse(cd))
        else
          super(cd)
        end
        self.errors.delete(:contents_delta)
      rescue => exc
        self.errors[:contents_delta] << exc.message
      end
    end
    
    # Build a query to fetch comments.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<ActiveRecord::Base,String,GlobalID>, ActiveRecord::Base,String,GlobalID] :only_commentables
    #  Limit the returned values to those members whose {#commentable} appears in this list.
    #  The elements in the array are objects, GlobalID instances, or strings containing an object fingerprint or
    #  a GlobalID representation. They are converted to object
    #  fingerprints with {Fl::Core::Query#convert_list_of_polymorphic_references}.
    #  A scalar value is converted to a one-element array before ID conversion.
    # @option opts [Array<ActiveRecord::Base,String,GlobalID>, ActiveRecord::Base,String,GlobalID] :except_commentables
    #  Limit the returned values to those members whose {#commentable} does not appear in this list.
    #  See above for a description of the possible values.
    # @option opts [Array<Object, String>, Object, String] :only_authors See the discussion of this
    #  option in {Fl::Core::Query#_expand_author_list}.
    # @option opts [Array<Object>, Object] :except_authors See the discussion of this
    #  option in {Fl::Core::Query#_expand_author_list}.
    # @option opts [Array<Object>, Object] :only_groups See the discussion of this
    #  option in {Fl::Core::Query#_expand_author_list}.
    # @option opts [Array<Object>, Object] :except_groups See the discussion of this
    #  option in {Fl::Core::Query#_expand_author_list}.
    # @option opts [Integer, Time, String] :updated_after selects comments updated after a given time.
    # @option opts [Integer, Time, String] :created_after selects comments created after a given time.
    # @option opts [Integer, Time, String] :updated_before selects comments updated before a given time.
    # @option opts [Integer, Time, String] :created_before selects comments created before a given time.
    # @option opts [Integer] :offset Sets the number of records to skip before returning;
    #  a +nil+ value causes the option to be ignored.
    #  Defaults to 0 (start at the beginning).
    # @option opts [Integer] :limit The maximum number of comments to return;
    #  a +nil+ value causes the option to be ignored.
    #  Defaults to all comments.
    # @option opts [String] :order A string containing the <tt>ORDER BY</tt> clause for the comments;
    #  a +nil+ value causes the option to be ignored.
    #  Defaults to <tt>updated_at DESC</tt>, so that the comments are ordered by modification time, 
    #  with the most recent one listed first.
    # @option opts [Symbol, Array<Symbol>, Hash] includes An array of symbols (or a single symbol),
    #  or a hash, to pass to the +includes+ method
    #  of the relation; see the guide on the ActiveRecord query interface about this method.
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
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(only_commentables: c, limit: 10)
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(only_commentables: c.fingerprint).limit(10)
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(only_commentables: c, order: nil).order('updated_at DESC').limit(10)
    #
    # @example Get the first 10 comments on a commentable from a given user (showing equivalent calls)
    #  c = get_commentable_object()
    #  u = get_user()
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(only_commentables: c, only_authors: u, order: 'created_at ASC, limit: 10)
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(only_commentables: c, only_authors: u.fingerprint, order: nil).order('created_at ASC').limit(10)
    #
    # @example Get all comments on a commentable not from a given user
    #  c = get_commentable_object()
    #  u = get_user()
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(only_commentables: c.to_global_id, except_authors: u)
    #
    # @example Get all comments from a given user that were created less than ten days ago
    #  u = get_user()
    #  t = Time.new
    #  t -= 10.days
    #  q = Fl::Core::Comment::ActiveRecord::Comment.build_query(only_authors: u.to_global_id.to_s, created_since: t)

    def self.build_query(opts = {})
      q = self

      if opts[:includes]
        i = (opts[:includes].is_a?(Array) || opts[:includes].is_a?(Hash)) ? opts[:includes] : [ opts[:includes] ]
        q = q.includes(i)
      end

      c_lists = partition_lists_of_polymorphic_references(opts, 'commentables')
      u_lists = _expand_actor_lists(opts, 'authors')

      if c_lists[:only_commentables]
        # If we have :only_commentables, the :except_commentables have already been eliminated, so all we need
        # is the only_commentables

        q = q.where('(commentable_fingerprint IN (:cl))', { cl: c_lists[:only_commentables] })
      elsif c_lists[:except_commentables]
        # since only_commentables is not present, we need to add the except_commentables

        q = q.where('(commentable_fingerprint NOT IN (:cl))', { cl: c_lists[:except_commentables] })
      end

      if u_lists[:only_ids]
        # If we have :only_ids, the :except_ids have already been eliminated, so all we need is the only_ids

        q = q.where('(author_fingerprint IN (:uids))', uids: u_lists[:only_ids])
      elsif u_lists[:except_ids]
        # since only_ids is nil, we need to add the except_ids

        q = q.where('(author_fingerprint NOT IN (:uids))', uids: u_lists[:except_ids])
      end

      ts = _date_filter_timestamps(opts)
      wt = []
      wta = {}
      if ts[:c_after_ts]
        wt << '(created_at > :c_after_ts)'
        wta[:c_after_ts] = ts[:c_after_ts].to_time
      end
      if ts[:u_after_ts]
        wt << '(updated_at > :c_after_ts)'
        wta[:u_after_ts] = ts[:u_after_ts].to_time
      end
      if ts[:c_before_ts]
        wt << '(created_at < :c_before_ts)'
        wta[:c_before_ts] = ts[:c_before_ts].to_time
      end
      if ts[:u_before_ts]
        wt << '(updated_at < :c_before_ts)'
        wta[:u_before_ts] = ts[:u_before_ts].to_time
      end
      if wt.count > 0
        q = q.where(wt.join(' AND '), wta)
      end

      order = (opts.has_key?(:order)) ? opts[:order] : 'updated_at DESC'
      q = q.order(order) if order

      offset = (opts.has_key?(:offset)) ? opts[:offset] : nil
      q = q.offset(offset) if offset.is_a?(Integer) && (offset > 0)

      limit = (opts.has_key?(:limit)) ? opts[:limit] : nil
      q = q.limit(limit) if limit.is_a?(Integer) && (limit > 0)

      q
    end

    # Get the number of comments returned by a query.
    # This method calls {.build_query} and then executes a `count` operation.
    #
    # @param opts [Hash] A Hash containing configuration options for the query. See the options for
    #  {.build_query} for details.
    #
    # @return [Integer] Returns the number of comments that would be returned by the query.

    def self.count_comments(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end

    private

    def populate_fingerprints()
      write_attribute(:author_fingerprint, self.author.fingerprint) if self.author
      write_attribute(:commentable_fingerprint, self.commentable.fingerprint) if self.commentable
    end

    def _bump_comment_count_callback()
      if self.commentable.respond_to?('_bump_comment_count')
        self.commentable.send('_bump_comment_count')
      end
    end

    def _drop_comment_count_callback()
      if self.commentable.respond_to?('_drop_comment_count')
        self.commentable.send('_drop_comment_count')
      end
    end

    def _update_commentable_timestamp()
      self.commentable.updated_at = Time.new
      self.commentable.save
    end
  end
end
