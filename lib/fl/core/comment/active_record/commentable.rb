module Fl::Core::Comment::ActiveRecord
  # ActiveRecord-specific functionality for the comment management extension module.

  module Commentable
    extend ActiveSupport::Concern
    include Fl::Core::Query

    # Build a query to fetch an object's comments.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Framework::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
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
    # @return If the query options are empty, the method returns the +comments+ association; if they are
    #  not empty, it returns an association relation.
    #  If +self+ does not seem to have a +comments+ association, it returns +nil+.
    #
    # @example Get the last 10 comments from all users (showing equivalent calls)
    #  c = get_commentable_object()
    #  q = c.comments_query(limit: 10)
    #  q = c.comments_query().limit(10)
    #  q = c.comments_query(order: nil).order('updated_at DESC').limit(10)
    #
    # @example Get the first 10 comments from a given user (showing equivalent calls)
    #  c = get_commentable_object()
    #  u = get_user()
    #  q = c.comments_query(only_authors: u, order: 'created_at ASC, limit: 10)
    #  q = c.comments_query(only_authors: u, order: nil).order('created_at ASC').limit(10)
    #
    # @example Get all comments not from a given user
    #  c = get_commentable_object()
    #  u = get_user()
    #  q = c.comments_query(except_authors: u)
    #
    # @example Get all comments from a given user that were created less than ten days ago
    #  c = get_commentable_object()
    #  u = get_user()
    #  t = Time.new
    #  t -= 10.days
    #  q = c.comments_query(only_authors: u, created_since: t)

    def comments_query(opts = {})
      return nil unless self.respond_to?(:comments)

      q = self.comments

      if opts[:includes]
        i = (opts[:includes].is_a?(Array) || opts[:includes].is_a?(Hash)) ? opts[:includes] : [ opts[:includes] ]
        q = q.includes(i)
      end

      u_lists = _expand_actor_lists(opts, 'authors')
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

    # Execute a query to fetch the number of comments associated with an object.
    # The number returned is subject to the configuration options +opts+; for example,
    # if <tt>opts[:only_authors]</tt> is defined, the return value is the number of comments for +self+
    # and created by the given authors.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
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
    #  Defaults to <tt>created_at DESC</tt>, so that the comments are ordered by creation time, 
    #  with the most recent one listed first.
    #
    # @return [Integer] Returns the number of comments that would be returned by the query.

    def comments_count(opts = {})
      q = comments_query(opts)
      (q.nil?) ? 0 : q.count
    end

    # Perform actions when the module is included.

    included do
    end
  end
end
