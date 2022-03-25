module Fl::Core::Test
  # Object helpers for testing.
  # Include this module to inject methods for use with (ideally [RSpec](https://rspec.info/)) test scripts:
  #
  # ```
  # RSpec.configure do |c|
  #   c.include Fl::Core::Test::ObjectHelpers
  # end
  # ```
  
  module ObjectHelpers
    # Get object identifiers.
    # Given an array of objects or hashes in *ol*, map it to an array of object identifiers.
    #
    # @param [Array<Object,Hash>] ol An array of objects or hashes.
    #
    # @return [Array<Number,nil>] Returns an array whose elements are the identifiers for the
    #  corresponding elements in *ol*. Elements in *ol* that don't have an identifier are mapped to +nil+.

    def obj_ids(ol)
      ol.map do |o|
        case o
        when Hash
          (o[:id]) ? o[:id] : o['id']
        else
          (o.respond_to?(:id)) ? o.id : nil
        end
      end
    end

    # Get object fingerprints.
    # Given an array of objects or hashes in *ol*, map it to an array of object fingerprints.
    #
    # @param [Array<Object,Hash>] ol An array of objects or hashes.
    #
    # @return [Array<Number,nil>] Returns an array whose elements are the identifiers for the
    #  corresponding elements in *ol*. Elements in *ol* that don't have an identifier are mapped to +nil+.

    def obj_fingerprints(ol)
      ol.map do |o|
        case o
        when Hash
          fp = (o[:fingerprint]) ? o[:fingerprint] : o['fingerprint']
          if fp.is_a?(String)
            fp
          else
            type = (o[:type]) ? o[:type] : o['type']
            id = (o[:id]) ? o[:id] : o['id']
            (type.nil? || id.nil?) ? nil : "#{type}/#{id}"
          end
        when String
          type, id = ActiveRecord::Base.split_fingerprint(o)
          (type.nil? || id.nil?) ? nil : o
        else
          (o.respond_to?(:fingerprint)) ? o.fingerprint : nil
        end
      end
    end

    # Get object names.
    # Given an array of objects or hashes in *ol*, map it to an array of names.
    #
    # @param [Array<Object,Hash>] ol An array of objects or hashes.
    #
    # @return [Array<String,nil>] Returns an array whose elements are the names for the
    #  corresponding elements in *ol*. Elements in *ol* that don't have a name are mapped to +nil+.

    def obj_names(ol)
      ol.map do |o|
        case o
        when Hash
          (o[:name]) ? o[:name] : o['name']
        else
          (o.respond_to?(:name)) ? o.name : nil
        end
      end
    end
  end
end
