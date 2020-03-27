require 'fl/google/recaptcha'

# Namespace for CAPTCHA support.
# This namespace defines APIs to manage the implementation of CAPTCHA used by the framework.
#
# Implementations of CAPTCHA define the following method:
#
# ```
# def verify(response, ip = nil)
# end
# ```
#
# where
#
# - *response* is a string containing the response as submitted by the form.
# - *ip* is a string containing an optional IP address for the requestor.
#
# The method returns a hash containing the response from the verification API, using the format
# returned by the Google RECAPTCHA API's response.
# In addition to the key/value pairs
# returned by the API, `error-messages` contains an array of error messages mapped from the
# error codes. Note that we use the Google RECAPTCHA return value, because it is the typical
# implementation used; others will just have to conform.

module Fl::Core::CAPTCHA
  # Factory for the framework CAPTCHA implementation.
  # We use a factory so that we can override the CAPTCHA implementation, for example for testing.
  #
  # @param [Hash] config A hash containing configuration options for the CAPTCHA object.
  #
  # @return [Object] Returns an instance of the CAPTCHA implementation. This implementation returns
  #  an instance of {Fl::Google::RECAPTCHA}.
  
  def self.factory(config = {})
    Fl::Google::RECAPTCHA.new(config)
  end
end
