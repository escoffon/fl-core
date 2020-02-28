# A concern to generate standardized success and error responses for an API-based controller.
# Include it in a controller code, like this:
#
# ```
# class ApplicationController < ActionController::Base
#   include Fl::Core::Concerns::Controller::ApiResponse
# end
# ```

module Fl::Core::Concerns::Controller::ApiResponse
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
  # - If *details* is provided, its value is copied into the **details** key.
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
    { _error: (details.is_a?(Hash)) ? _error.merge({ details: details }) : _error }
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

  # Class methods.

  class_methods do
  end
  
  # Include callback.
  # This method is currently empty.

  included do
  end
end
