# A concern to generate standardized success and error responses for an API-based controller.
# Include it in a controller or service object code, like this:
#
# ```
# class ApplicationController < ActionController::Base
#   include Fl::Core::Concerns::Service::ApiResponse
# end
# ```
#
# The base service object {Fl::Core::Service::Base} includes this concern, so that there is no need to do so
# in its subclasses.

module Fl::Core::Concerns::Service::ApiResponse
  extend ActiveSupport::Concern

  protected

  # Generate success response data.
  # The success response consists of a hash containing the keys `:_status` (which identifies the response as being
  # successful), and **:payload**.
  # The value of `:_status` is a hash containing the following key/value pairs:
  #
  # - **:message** is the value of *message*, if non-nil.
  #
  # If *payload* is provided, its value is copied into the **:payload** key.
  #
  # @param message [String] A string containing the status message.
  # @param payload [Hash] A hash containing payload data; the contents are response-dependent.
  #
  # @return [Hash] Returns a hash as described above.
  
  def success_response_data(message, payload = nil)
    rv = {
      _status: { }
    }
    rv[:_status][:message] = message if message.is_a?(String) && (message.length > 0)
    rv[:payload] = payload if payload.is_a?(Hash)
    rv
  end

  # Generate error response data.
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
  # @param message [String] A string containing the error message.
  # @param details [Hash] A hash containing additional information; the contents are response-dependent.
  #
  # @return [Hash] Returns a hash as described above.
  
  def error_response_data(type, message = nil, details = nil)
    _error = {
      type: type
    }
    _error[:message] = message if message.is_a?(String) && (message.length > 0)

    if details.is_a?(Hash)
      # We need to save a copy just in case the caller has passed something like obj.errors.messages,
      # which is reset when the object is reset

      _error[:details] = details.dup
    end
    
    { _error: _error }
  end

  # Generate error response data from an exception.
  # The error response consists of a hash containing the key `:_error` (which identifies the response as an error).
  # The value of `:_error` is a hash containing the following key/value pairs:
  #
  # - **:type** is the value of *type* (converted to a string), and it "tags" the error; this is typically used
  #   by client software to error-dependent actions.
  # - **:message** is the value of *message*, if non-nil.
  # - **:details** is populated with the exception message and, on development and test Rails environments, the
  #   exception backtrace.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param message [String] A string containing the error message.
  # @param exc [Exception] The exception object.
  #
  # @return [Hash] Returns a hash as described above.
  
  def exception_response_data(type, message = nil, exc = nil)
    _error = {
      type: type
    }
    _error[:message] = message if message.is_a?(String) && (message.length > 0)

    if exc.is_a?(Exception)
      d = { message: exc.message }
      d[:backtrace] = JSON.generate(exc.backtrace) if Rails.env.development? || Rails.env.test?
      _error[:details] = d
    end
    
    { _error: _error }
  end

  # Render success response data.
  # The success response data is built using {#success_response_data}, and it is then "rendered" as a JSON
  # string.
  #
  # @param message [String] A string containing the status message.
  # @param status [Integer,Symbol] The HTTP status code to set; a `nil` value is converted to 200.
  # @param payload [Hash] A hash containing payload data; the contents are response-dependent.
  
  def render_success_response(message, status = nil, payload = nil)
    render json: success_response_data(message, payload), status: (status.nil?) ? 200 : status
  end

  # Render error response data.
  # The error response data is built using {#error_response_data}, and it is then "rendered" as a JSON
  # string.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param message [String] A string containing the error message.
  # @param status [Integer,Symbol] The HTTP status code to set; a `nil` value is converted to 400.
  # @param details [Hash] A hash containing additional information; the contents are response-dependent.
  #
  # @return [Hash] Returns a hash as described above.
  
  def render_error_response(type, message, status = 400, details = nil)
    render json: error_response_data(type, message, details), status: (status.nil?) ? 400 : status
  end

  # Hash support: returns a hash representation of an object, for the current user.
  #
  # @param obj [Object] The object whose +to_hash+ method to call. The object should have included
  #  {Fl::Core::ModelHash}.
  # @param hash_opts [Hash] The hashing options for +to_hash+.
  #
  # @return [Hash] Returns a hash representation of _obj_.

  def hash_one_object(obj, hash_opts)
    obj.to_hash(current_user, hash_opts)
  end

  # Hash support: returns an array of hash representations of objects, for the current user.
  #
  # @param ary [Array<Object>] The array of objects whose +to_hash+ method to call. The objects should have
  #  included {Fl::Core::ModelHash}.
  # @param hash_opts [Hash] The hashing options for +to_hash+.
  #
  # @return [Array<Hash>] Returns an array of hash representations of _ary_.

  def hash_objects(ary, hash_opts)
    ary.map { |r| r.to_hash(current_user, hash_opts) }
  end

  # Get the response format.
  #
  # @return Returns the response format from the **:format** key in the `params` hash; if no **:format** key,
  #  returns **:html**.

  def response_format()
    params.has_key?(:format) ? params[:format] : :html
  end

  # Check if we are displaying HTML.
  #
  # @return Returns `true` if the response is expected to display HTML, `false` otherwise.

  def html_format?()
    self.response_format == :html
  end

  # Check if we have a JSON request.
  #
  # @return Returns `true` if the request is marked as JSON.

  def json_request?()
    request.format.json?
  end

  # Class methods.

  class_methods do
  end
  
  # Include callback.
  # This method is currently empty.

  included do
  end
end
