# Permission checker for comments.
  
class Fl::Core::Comment::Checker < Fl::Core::Access::Checker
  # Initializer.

  def initialize()
    super()
  end

  # Configure the including class.
  # Currently empty: calls `super` for completeness.
  #
  # @param base [Class] The class object in whose context the `has_access_control` macro is executed.

  def configure(base)
    super(base)
  end
  
  # Run an access check.
  # The following checks are performed:
  #
  # 1. For {Fl::Core::Access::Permission::Index}, returns `false`: the policy is that comments may only be listed
  #    in the context of a commentable, and therefore the appropriate permission is
  #    {Fl::Core::Access::Permission::IndexContents}.
  # 2. For {Fl::Core::Access::Permission::Create}, returns `false`: the policy is that comments may only be
  #    created in the context of a commentable, and therefore the appropriate permission is
  #    {Fl::Core::Access::Permission::CreateContents}.
  # 3. For {Fl::Core::Access::Permission::Read}, returns `true` if *actor* has read access to the commentable
  #    for *asset*, or if *asset* does not support access control.
  # 4. For {Fl::Core::Access::Permission::Write} and {Fl::Core::Access::Permission::Delete}, returns `false`
  #    because we currently do not allow editing or deleting comments.
  # 5. For {Fl::Core::Comment::Permission::IndexComments}, returns `true` if *actor* has read access to the
  #    comment itself: only actors that have read access to *asset* can list its (sub)comments.
  #    It also returns `true` if *asset* does not support access control.
  # 6. For {Fl::Core::Comment::Permission::CreateComments}, returns `true` if *actor* has read access to the
  #    comment itself: only actors that have read access to *asset* can create (sub)comments.
  #    It also returns `true` if *asset* does not support access control.
  # 7. Returns `false` for all other values of *permission*.
  #
  # Note that, for {Fl::Core::Access::Permission::Read}, {Fl::Core::Access::Permission::IndexContents},
  # and {Fl::Core::Access::Permission::CreateContents}, where we check for read access to *asset*, the permission
  # check is moved up the comment hierarchy until the top level commentable (a non-comment) is reached.
  #
  # @param permission [Symbol,String,Fl::Core::Access::Permission,Class] The requested permission.
  #  See {Fl::Core::Access::Helper.permission_name}.
  # @param actor [Object,String] The actor requesting *permission*.
  #  Implementations may accept string values, which should be object fingerprints or GlobalIDs.
  # @param asset [Object,Class,String] The target of the request (the asset for which *permission* is requested).
  #  Implementations may accept string values, which should be object fingerprints or GlobalIDs.
  #  In this case, *asset* is a comment.
  # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
  #  checker parameter.
  #
  # @return [Boolean,nil] An access check method is expected to return a boolean value `true` if access
  #  rights were granted, and `false` if access rights were denied.
  #  Under some conditions, it may elect to return `nil` to indicate that there was some kind of error
  #  when checking for access; a `nil` return value indicates that access rights were not granted,
  #  and it *must* be interpreted as such.

  def access_check(permission, actor, asset, context = nil)
    pname = Fl::Core::Access::Helper.permission_name(permission)
    return false if pname.nil?

    case pname
    when Fl::Core::Access::Permission::Index::NAME, Fl::Core::Access::Permission::Create::NAME
      return false
    when Fl::Core::Access::Permission::Read::NAME
      return true unless asset.commentable.respond_to?(:has_permission?)
      return true if asset.author_fingerprint == actor.fingerprint
      return asset.commentable.has_permission?(Fl::Core::Access::Permission::Read::NAME, actor, context)
    when Fl::Core::Access::Permission::Write::NAME, Fl::Core::Access::Permission::Delete::NAME
      return false
    when Fl::Core::Comment::Permission::IndexComments::NAME, Fl::Core::Comment::Permission::CreateComments::NAME
      return true unless asset.commentable.respond_to?(:has_permission?)
      return true if asset.author_fingerprint == actor.fingerprint
      return asset.commentable.has_permission?(Fl::Core::Access::Permission::Read::NAME, actor, context)
    else
      return false
    end
  end
end
