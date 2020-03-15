# A concern to extract success and error response data from service object status.
# Include it in a controller code, like this:
#
# ```
# class ApplicationController < ActionController::Base
#   include Fl::Core::Concerns::Controller::ServiceStatus
# end
# ```

module Fl::Core::Concerns::Controller::ServiceStatus
  extend ActiveSupport::Concern

  protected

  # Generate error response data from a service status.
  # The error response consists of a hash containing the key `:_error` (which identifies the response as an error).
  # The value of `:_error` is a hash containing the following key/value pairs:
  #
  # - **:type** is the value of *type* (converted to a string), and it "tags" the error; this is typically used
  #   by client software to error-dependent actions.
  # - **:message** is the value of *message*, if non-nil.
  # - If *details* is provided, a duplicate of its value is placed into the **details** key.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param service [Fl::Core::Service::Base] The service object from which to extract error data.
  #
  # @return [Hash] Returns a hash as described above.
  
  def error_response_data_from_service(type, service)
    _error = {
      type: type
    }

    rd = service.status_response_data
    rde = rd[:_error] || { }
    _error[:message] = rde[:message] if rde[:message].is_a?(String)

    if rd[:details].is_a?(Hash)
      # We need to save a copy just in case the caller has passed something like obj.errors.messages,
      # which is reset when the object is reset

      _error[:details] = rd[:details].dup
    end
    
    { _error: _error }
  end

  # Render error response data from a service status.
  # The error response data is built using {#error_response_data_from_service}, and it is then "rendered" as a JSON
  # string.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param service [Fl::Core::Service::Base] The service object from which to extract error data.
  # @param status [Integer,Symbol] The HTTP status code to set; a `nil` value is converted to 400.
  #
  # @return [Hash] Returns a hash as described above.
  
  def render_error_response_from_service(type, service, status = 400)
    render json: error_response_data_from_service(type, service), status: (status.nil?) ? 400 : status
  end

  # Class methods.

  class_methods do
  end
  
  # Include callback.
  # This method is currently empty.

  included do
  end
end
