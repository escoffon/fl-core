# The exception raised when a malformed query string is detected.

class Fl::Core::TextSearch::MalformedQuery < RuntimeError
  # The query string.
  # @return [String] Returns the value of the *qs* parameter in {#initialize}.

  attr_reader :query

  # The error location.
  # @return [Integer] Returns the index of the (rough) location where the error occurred.

  attr_reader :location
      
  # The initializer.
  # generates a default message.
  #
  # @param qs [String] The query string.
  # @param idx [Integer] The (rough) index to the location where the error was detected.

  def initialize(qs, idx)
    @query = qs
    @location = idx
        
    super("malformed query string '#{qs}'")
  end
end
