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

  class Comment < Fl::Core::ApplicationRecord
    include Fl::Core::Access::Access
    include Fl::Core::Comment::Commentable
    include Fl::Core::Comment::ActiveRecord::Commentable
    include Fl::Core::Comment::Common

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
      begin
        attrs[:author] = Fl::Core::Comment::Helper.author_from_parameter(attrs)
      rescue => exc
        self.errors[:author] << exc.message
      end

      begin
        attrs[:commentable] = Fl::Core::Comment::Helper.commentable_from_parameter(attrs)
      rescue => exc
        self.errors[:commentable] << exc.message
      end

      begin
        if attrs[:contents_delta].is_a?(String)
          attrs[:contents_delta] = JSON.parse(attrs[:contents_delta])
        end
      rescue => exc
        self.errors[:contents_delta] << exc.message
      end
        
      super(attrs)
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
  end
end
