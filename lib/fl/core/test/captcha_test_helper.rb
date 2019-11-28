module Fl::Core::Test
  # Helper module for testing services (and other code) that use CAPTCHA.
  # Include this module to define a subclass of {Fl::Core::CAPTCHA} that implements a test vaerifier,
  # and to register it as the one created by the factory method {Fl::Core::CAPTCHA.factory}.

  module CAPTCHATestHelper
    # A local CAPTCHA service that mocks a CAPTCHA verification call.

    class CAPTCHA
      # Initializer.
      #
      # @param [Hash] config A hash containing configuration options.

      def initialize(config = {})
      end

      # Validate the response.
      # If _response_ is the string +fail+, validation fails; otherwise, validation succeeds.
      #
      # @param [String] response The response as submitted by the form.
      # @param [String] ip An optional IP address for the requestor.
      #
      # @return [Hash] Returns a hash containing the API's response.

      def verify(response, ip = nil)
        if response == 'fail'
          { 
            'success' => false,
            'error-codes' => [ 'invalid-input-response' ],
            'error-messages' => [ 'invalid-input-response' ]
          }
        else
          { 'success' => true }
        end
      end
    end

    # Set the CAPTCHA factory to return an instnce of {CAPTCHA}.

    def self.register_factory()
      Fl::Core::CAPTCHA.class_eval do
        def self.factory(config = {})
          Fl::Core::Test::CAPTCHATestHelper::CAPTCHA.new(config)
        end
      end
    end
  end
end
