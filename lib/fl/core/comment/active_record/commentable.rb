module Fl::Core::Comment::ActiveRecord
  # ActiveRecord-specific functionality for the comment management extension module.

  module Commentable
    extend ActiveSupport::Concern

    # Build a query to fetch an object's comments.
    # This method wraps a call to {Fl::Core::Comment::ActiveRecord::Comment.build_query} using the parameters
    # in *opts* and setting the **:commentables:only** filter to `self`.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {Fl::Core::Comment::ActiveRecord::Comment.build_query}.
    #
    # @return [ActiveRecord::Relation] Returns the relation corresponding to the given query parameters.
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
    #  q = c.comments_query(filters: { authors: { only: u } }, order: 'created_at ASC, limit: 10)
    #  q = c.comments_query(filters: { authors: { only: u ] }, order: nil).order('created_at ASC').limit(10)
    #
    # @example Get all comments not from a given user
    #  c = get_commentable_object()
    #  u = get_user()
    #  q = c.comments_query(filters: { authors: { except: u } })
    #
    # @example Get all comments from a given user that were created less than ten days ago
    #  c = get_commentable_object()
    #  u = get_user()
    #  t = Time.new
    #  t -= 10.days
    #  q = c.comments_query(filters: { authors: { only: u }, created: { after: t } })

    def comments_query(opts = {})
      qo = opts.dup
      filters = qo.delete(:filters) || { }
      filters.delete(:except_commentables)
      filters[:commentables] = { only: self }
      qo[:filters] = filters
      return Fl::Core::Comment::ActiveRecord::Comment.build_query(qo)
    end

    # Build a query and return its count.
    # This method wraps a call to {Fl::Core::Comment::ActiveRecord::Comment.build_query} using the parameters
    # in *opts* and setting **:only_commentables** to `self`.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {Fl::Core::Comment::ActiveRecord::Comment.build_query}.
    #
    # @return [Integer] Returns the number of comments that would be returned by the query.

    def comments_count(opts = {})
      return comments_query(opts).count
    end

    # Perform actions when the module is included.

    included do
    end
  end
end
