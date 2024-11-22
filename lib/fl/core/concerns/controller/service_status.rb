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
  #   by client software to perform error-dependent actions.
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

    if rde[:details].is_a?(Hash)
      # We need to save a copy just in case the caller has passed something like obj.errors.messages,
      # which is reset when the object is reset

      _error[:details] = rde[:details].dup
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

  # Generate error response data from an exception.
  # The error response consists of a hash containing the key `:_error` (which identifies the response as an error).
  # The value of `:_error` is a hash containing the following key/value pairs:
  #
  # - **:type** is the value of *type* (converted to a string), and it "tags" the error; this is typically used
  #   by client software to perform error-dependent actions.
  # - **:exception** is the class name of the exception.
  # - **:message** is the value of the **:message** method for *exc*.
  # - **:details** is a hash containing the key/value pairs listed below.
  #
  # The **:details** hash contains the following key/value pairs:
  #
  # - **:backtrace** is the value of the **:backtrace** method for *exc*.
  #
  # This method is used by the {#rescue_controller_exception} handler to render an error report.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param exc [Exception] The exception from which to generate the error data.
  #
  # @return [Hash] Returns a hash as described above.
  
  def error_response_data_from_exception(type, exc)
    _error = {
      type: type,
      exception: exc.class.name,
      message: exc.message,
      details: {
        backtrace: exc.backtrace
      }
    }
  
    return { _error: _error }
  end

  # Render error response data from an exception.
  # The error response data is built using {#error_response_data_exception}, and it is then "rendered" as a JSON
  # string.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param exc [Exception] The exception from which to generate the error data.
  # @param status [Integer,Symbol] The HTTP status code to set; a `nil` value is converted to 400.
  #
  # @return [Hash] Returns a hash as described above.
  
  def render_error_response_from_exception(type, exc, status = 400)
    render json: error_response_data_from_exception(type, exc), status: (status.nil?) ? 400 : status
  end

  # An exception handler to render an exception error response.
  # This handler is meant to be registered with a `rescue_from` directive, like this:
  #
  # ```
  #  class ApplicationController < ActionController::Base
  #    include Fl::Core::Concerns::Controller::ServiceStatus
  #  
  #    rescue_from MyException, MyOtherException, with: :rescue_controller_exception
  #  end
  # ```
  #
  # It uses the error "type" `internal_error`.
  # If *exc* is a ActiveRecord::RecordNotFound, it sets the status to 404, for consistency with Rails;
  # otherwise, it uses the default status 400.
  #
  # @param exc [Exception] The exception that triggered the call.
  
  def rescue_controller_exception(exc)
    case exc
    when ActiveRecord::RecordNotFound
      render_error_response_from_exception('internal_error', exc, 404)
    else
      render_error_response_from_exception('internal_error', exc)
    end
  end
  
  # Class methods.

  class_methods do
  end
  
  # Include callback.
  # This method is currently empty.

  included do
  end
end
