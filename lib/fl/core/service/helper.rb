module Fl::Core::Service
  # Helper for service objects.

  module Helper
    # Normalize one of more array parameters.
    # This helper method handles various representations of an array parameter as generated by clients and
    # converted by the Rails framework.
    # In particular, it performs the following conversions:
    #
    # - A string value is assumed to be a JSON representation and parsed as such.
    # - A hash or `ActionController::Parameters` is assumed to have been converted from a payload
    #   representation like `a[0]=abcd&a[1]=cdef`, which the Rails code seems to intepret as a hash where the
    #   keys are strings containing the index value.
    # - An array is left alone.
    #
    # The method normalizes the value to an array if possible, and overwrites it in *params*; if not possible,
    # the value is left as is.
    #
    # @param params [Hash,ActionController::Parameters] The submission parameters.
    # @param names [String,Symbol,Array<String,Symbol>] The list of parameters whose value to normalize.
    #
    # @return [Hash,ActionController::Parameters] Returns *params*, some of whose parameters may have been
    #  normalized.

    def self.normalize_array_params(params, names)
      names = [ names ] unless names.is_a?(Array)

      names.each do |n|
        v = params[n] || params[n.to_sym] || params[n.to_s]
        case v
        when Array
          # leave as-is
        when Hash, ActionController::Parameters
          # If all the keys are string representation of integers, or integers, convert

          not_int = v.keys.select { |e| !(e.is_a?(Integer) || (e.is_a?(String) && (e =~ /^[0-9]$/))) }
          if not_int.count == 0
            a = [ ]
            v.each do |vk, vv|
              idx = vk.to_i
              a[idx] = vv
            end

            params[n] = a
          end
        when String
          # assume it's a JSON representation

          params[n] = JSON.parse(v)
        end
      end

      return params
    end

    # Include hook.

    def self.included(base)
      base.class_eval do
      end
    end
  end
end