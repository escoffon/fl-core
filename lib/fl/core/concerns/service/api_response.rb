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
#
# ### Overview of the API
#
# Each API call returns a hash containing information about the call (this hash is typically converted to a
# JSON object in the controller code).
#
# If the call succeeds, the hash contains two keys, **:_status** and **:payload**. The value for **:_status** is
# a hash that contains the optional key **:message**, a string with a message about the call resolution.
# The value for **:payload** is call dependent, but typically it is a hash containing additional information;
# for example, a login call may return a representation of the logged in user.
#
# On error, the hash contains the key **:_error**, which is a hash of error information containing the keys
# **:type**, **:message**, and **:details**. **:type** is required and its value is a string containing a call
# dependent error name; **:message** is an optional (but typically present) key whose value is a message string;
# and the optional **:details** key contain call dependent additional information.
# A very common value for **:details** is a hash containing the two keys **:messages** and **:full_messages**.
# These are the equivalent of the return value from the `errors.messages` and `errors.full_messages` methods
# in an ActiveRecord object (and therefore are, respectively, a hash of error messages per attribute, and an
# array of error messages).
#
# The methods defined by this concern implement support for generating the API responses.
# At the top level are {#render_success_response} and {#render_error_response}, which can be called from controller
# code to render API response objects.
# One level below are {#success_response_data}, {#error_response_data}, and {#exception_response_data},
# which package the API response hash
# as described above; they are used by {#render_success_response} and {#render_error_response}.
# Then there is a set of methods to generate fragments of the response data: {#error_messages} generates the
# **:messages**/**:full_messages** error detail hash from an ActiveRecord object;
# {#hash_one_object} and {#hash_objects} generate hash representations of objects that respond to
# {Fl::Core::ModelHash#to_hash}.
# Finally, a few utility methods for detecting request properties: {#response_format}, {#html_format?},
# and {#json_request?}.

module Fl::Core::Concerns::Service::ApiResponse
  extend ActiveSupport::Concern

  protected

  # Generate an error message hash from an ActiveRecord instance.
  # This method returns a hash containing two keys: **:messages** is the value of `obj.errors.messages`, and
  # **:full_messages** is the value of `obj.errors.full_messages`.
  #
  # @param obj [ActiveRecord::Base,ActiveModel::Errors] The object whose errors to extract. If it is an instance
  #  of ActiveRecord::Base, use the value returned by `obj.errors`; otherwise, use it as is.
  #
  # @return [Hash] Returns a hash as described above.

  def error_messages(obj)
    if obj.is_a?(ActiveRecord::Base)
      return { messages: obj.errors.messages, full_messages: obj.errors.full_messages }
    elsif obj.is_a?(ActiveModel::Errors)
      return { messages: obj.messages, full_messages: obj.full_messages }
    else
      return { }
    end
  end
  
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
  # The contents of the **details** key depend on the type of *details*:
  #
  #     - If *details* is an instance of ActiveModel::Errors, the generated **details** key is a hash containing
  #       the two keys **:messages** and **:full_messages**, as generated from the equivalent methods in
  #       ActiveModel::Errors.
  #     - If *details* is an instance of ActiveRecord::Base, the generated **details** key is created as above,
  #       using the value returned by *details.errors*.
  #     - If *details* is an exception, **details** is a hash containing **:messages** and **:full_messages**.
  #       In this case, the **:messages** key is a hash containing one key (**:exception**) whose value is
  #       *details.message*, and **:full_messages** is an array containing a single message (also from
  #       *details.message*).
  #       Additionally, in a Rails development or test environment an additional key **:backtrace** is generated
  #       that contains the exception trace.
  #     - Finally, if *details* responds to `each`, the contents of *details* are duplicated in the **:details** key.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param message [String] A string containing the error message.
  # @param details [Hash,ActiveModel::Errors,ActiveRecord::Base,Exception] An object containing additional
  #  information; the contents are response-dependent. See above for a description of how the details are extracted.
  #
  # @return [Hash] Returns a hash as described above.
  
  def error_response_data(type, message = nil, details = nil)
    _error = {
      type: type
    }
    _error[:message] = message if message.is_a?(String) && (message.length > 0)

    if details.is_a?(ActiveModel::Errors) || details.is_a?(ActiveRecord::Base)
      _error[:details] = error_messages(details)
    elsif details.is_a?(Exception)
      _error[:details] = { messages: { exception: details.message }, full_messages: [ details.message ] }
      _error[:details][:backtrace] = JSON.generate(details.backtrace) if Rails.env.development? || Rails.env.test?
    else
      # Rails 6.1 seems to have changed the class of errors.messages to ActiveModel::DeprecationHandlingMessageHash,
      # so let's instead check if details responds to :each, and if so copy it by iteration
    
      if details.respond_to?(:each)
        # We need to save a copy just in case the caller has passed something like obj.errors.messages,
        # which is reset when the object is reset.

        d = { }
        details.each do |kvp|
          k, v = kvp
          d[k] = v
        end
        _error[:details] = d
      end
    end
    
    { _error: _error }
  end

  # Generate error response data from an exception.
  # Because of recent changes to {#error_response_data} to support exception details, this method is just
  # a wrapper around {#error_response_data} for backward compatibility with existing client code.
  #
  # @param type [String,Symbol] A string or symbol that tags the type of error; for example: `'not_found'` or
  #  `:authentication_failure`.
  # @param message [String] A string containing the error message.
  # @param exc [Exception] The exception object.
  #
  # @return [Hash] Returns a hash as described in {#error_response_data}.
  
  def exception_response_data(type, message = nil, exc = nil)
    return error_response_data(type, message, exc)
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
