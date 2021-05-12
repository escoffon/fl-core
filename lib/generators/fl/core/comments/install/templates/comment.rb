# This is the comment object class that extends and overrides the core comment object functionality.
# It assumes that we are using ActiveRecord.

class <%=@comment_object_class%> < Fl::Core::Comment::ActiveRecord::Comment
  # Uncomment and modify this line to change the properties returned by the commentable hash
  # in a to_hash call. The implementation shown here is the default.

  # def self.default_commentable_to_hash_options(commentable)
  #   return { verbosity: :minimal }
  # end
end
