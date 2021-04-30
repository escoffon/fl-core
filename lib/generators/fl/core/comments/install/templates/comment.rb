# This is the comment object class that extends and overrides the core comment object functionality.
# It assumes that we are using ActiveRecord.

class <%=@comment_object_class%> < Fl::Core::Comment::ActiveRecord::Comment
end
