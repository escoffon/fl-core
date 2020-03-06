module Fl::Core
  # Namespace for service objects.
  # Service objects implement the server work that is often placed in the controller objects; this is
  # done for two reasons:
  #
  # 1. To separate processing of input parameters and generation of responses (which is left in the
  #    controller) from the implementation of the call (which is now in the service object).
  # 2. Thanks to this separation, it should be possible to make service calls outside of the context of
  #    a controller (and therefore of a request).

  module Service
    # Status: success.
    OK = :ok

    # Status: failure: an object was not found in the database.
    NOT_FOUND = :not_found

    # Status: failure: the actor did not have permission on an object.
    FORBIDDEN = :forbidden

    # Status: failure: an operation on an object failed.
    UNPROCESSABLE_ENTITY = :unprocessable_entity

    # Status: failure: general error.
    BAD_REQUEST = :bad_request

    # Status: failure: authentication required.
    UNAUTHORIZED = :unauthorized
  end
end

require 'fl/core/service/base'
require 'fl/core/service/nested'

