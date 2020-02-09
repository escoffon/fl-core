require 'digest'

# Helper methods for digests.
# {.flatten} generates a string containing the "flattened" representation of a value; this string is suitable
# for generating a digest of the value.
# The modules {MD5} and {SHA1} define methods for generating a digest from a value.

module Fl::Core::DigestHelper
  # Flatten an argument into a string.
  # Generates a string that contains a representation of the value.
  #
  # - A scalar value (string, symbol, number, and so on) is converted to a string via `to_s` and returned.
  # - An array is converted by calling {.flatten} for each element, and returning a string that joins the
  #   converted elements.
  # - For a hash value, keys are sorted and the resulting array is processed similarly to an array value.
  #   Note that, since the keys are sorted, the two hashes `{ a: 1, b: 2 }` and
  #   `{ b: 2, a: 1 }` are flattened to the same representation; this is important, because digests of the
  #   flattened representation for the two hashes are identical, and therefore can be used to compare them.
  #
  # @param value [any] The value to flatten, as outlined above.
  #
  # @return [String] Returns the flattened value.

  def self.flatten(value)
    if value.is_a?(Array)
      '[' + value.map do |e|
        self.flatten(e)
      end.join(',') + ']'
    elsif value.is_a?(Hash)
      '{' + value.keys.sort.reduce([ ]) do |acc, k|
        acc << "#{k}=>#{self.flatten(value[k])}"
        acc
      end.join(',') + '}'
    elsif value.nil?
      'nil'
    else
      value.to_s
    end
  end

  # MD5 digest methods.

  module MD5
    # Generate an MD5 hash of an argument (raw binary).
    # Flattens the contents of *value* into a string using {.flatten} and then generates an MD5 hash of the
    # flattened value.
    #
    # @param value [any] The value to hash; see {Fl::Core::DigestHelper.flatten}.
    #
    # @return [String] Returns the binary representation of the MD5 hash of *value*.

    def self.digest(value)
      Digest::MD5.digest(Fl::Core::DigestHelper.flatten(value))
    end
    
    # Generate an MD5 hash of an argument (hex representation).
    # Flattens the contents of *value* into a string using {.flatten} and then generates an MD5 hash of the
    # flattened value.
    #
    # @param value [any] The value to hash; see {Fl::Core::DigestHelper.flatten}.
    #
    # @return [String] Returns the hex representation of the MD5 hash of *value*.

    def self.hexdigest(value)
      Digest::MD5.hexdigest(Fl::Core::DigestHelper.flatten(value))
    end
    
    # Generate an MD5 hash of an argument (base 64 representation).
    # Flattens the contents of *value* into a string using {.flatten} and then generates an MD5 hash of the
    # flattened value.
    #
    # @param value [any] The value to hash; see {Fl::Core::DigestHelper.flatten}.
    #
    # @return [String] Returns the base 64 representation of the MD5 hash of *value*.

    def self.base64digest(value)
      Digest::MD5.base64digest(Fl::Core::DigestHelper.flatten(value))
    end
  end

  # SHA-1 digest methods.

  module SHA1
    # Generate an SHA-1 hash of an argument (raw binary).
    # Flattens the contents of *value* into a string using {.flatten} and then generates an SHA-1 hash of the
    # flattened value.
    #
    # @param value [any] The value to hash; see {Fl::Core::DigestHelper.flatten}.
    #
    # @return [String] Returns the binary representation of the SHA-1 hash of *value*.

    def self.digest(value)
      Digest::SHA1.digest(Fl::Core::DigestHelper.flatten(value))
    end
    
    # Generate an SHA-1 hash of an argument (hex representation).
    # Flattens the contents of *value* into a string using {.flatten} and then generates an SHA-1 hash of the
    # flattened value.
    #
    # @param value [any] The value to hash; see {Fl::Core::DigestHelper.flatten}.
    #
    # @return [String] Returns the hex representation of the SHA-1 hash of *value*.

    def self.hexdigest(value)
      Digest::SHA1.hexdigest(Fl::Core::DigestHelper.flatten(value))
    end
    
    # Generate an SHA-1 hash of an argument (base 64 representation).
    # Flattens the contents of *value* into a string using {.flatten} and then generates an SHA-1 hash of the
    # flattened value.
    #
    # @param value [any] The value to hash; see {Fl::Core::DigestHelper.flatten}.
    #
    # @return [String] Returns the base 64 representation of the SHA-1 hash of *value*.

    def self.base64digest(value)
      Digest::SHA1.base64digest(Fl::Core::DigestHelper.flatten(value))
    end
  end
end
