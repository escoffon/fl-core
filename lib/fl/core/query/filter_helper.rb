module Fl::Core::Query
  # A module that defines a number of support methods for filter generation.
  # These methods are kept separately for possible use by other classes, although {Fl::Core::Query::Filter}
  # is its main client.

  module FilterHelper
    # Normalize a boolean query flag.
    # This method accepts a flag value in multiple formats, and converts it to `true`, `false`, or `nil`.
    #
    # @param f [Boolean,Numeric,String,nil] The flag value. If a boolean, it is returned as is.
    #  If a numeric value, it returns `true` if f != 0, and `false` otherwise; therefore, a numeric
    #  value has the same semantics as numeric to boolean conversion in C.
    #  If a string value, and the string is made up wholly of digits, the value is converted to an
    #  integer and processed as for numeric values.
    #  Otherwise, the strings `true`, `t`, `yes`, and `y` are converted to `true`, and `false`, `f`,
    #  `no`, and `n` are converted to `false`. A `nil` value is converted to `false`.
    #  Any other value is also converted to `nil` to indicate that this was not a valid boolean flag.
    #
    # @return [Boolean, nil] Returns a boolean value as outlined above. A `nil` return value indicates that the
    #  flag *f* is not in one of the accepted formats.
    
    def self.boolean_query_flag(f)
      case f
      when TrueClass, FalseClass
        f
      when Numeric
        f != 0
      when String
        if f =~ /^[0-9]+$/
          f.to_i != 0
        elsif f =~ /^t(rue)?$/i
          true
        elsif f =~ /^f(alse)?$/i
          false
        elsif f =~ /^y(es)?$/i
          true
        elsif f =~ /^n(o)?$/i
          false
        else
          nil
        end
      when NilClass
        false
      else
        nil
      end
    end

    # Checks that a class name and object identifier are acceptable.
    # This method runs the check as follows:
    #
    # 1. If *klass* is `nil`, returns *id* as an integer.
    # 2. Convert *klass* and *cname* to class objects if needed, then check if *cname* is the same of *klass*,
    #    or a subclass of *klass*. If so, returns *id* as an integer.
    # 3. Otherwise, return `nil`.
    #
    # @param cname [String,Class] A class name, or a class object; this is the declared type of the object.
    # @param id [Integer,String,nil] The declared object identifier.
    # @param klass [String,Class] A class name, or a class object, for the target class.
    #
    # @return [Integer,nil] If the cheks succeed, returns *id* as an integer value; otherwise, returns `nil`.
    
    def self.check_object_class_and_id(cname, id, klass)
      return nil if cname.nil? || id.nil?
      return id.to_i if klass.nil?

      begin
        kc = (klass.is_a?(String)) ? Object.const_get(klass) : klass
        c = (cname.is_a?(String)) ? Object.const_get(cname) : cname
        return (c <= kc) ? id.to_i : nil
      rescue => x
        return nil
      end
    end

    # Extract an object identifier from a parameter.
    # The method runs a number of checks until one succeeds:
    #
    # 1. If *r* responds to **:id**, call the method to get the identifier, then run the class check if *klass* is
    #    non-nil.
    # 2. If *r* is an integer, or a string containing only integers, it returns *r*, converted to an integer value;
    #    no class checking is done, since there is no class information available.
    # 3. If *r* is a SignedGlobalID or GlobalID, extract the identifier from its URI; if *klass* is non-nil, check
    #    that the declared class in the URI is the same as *klass*.
    # 4. If *r* is a string starting with `gid://`, then this is a string representation of a GlobalID: extract
    #    the identifier and class name from it, then run the class check if *klass* is non-nil.
    # 5. Split *r* as a fingerprint; if the `id` component is non-nil, run the class check if *klass* is non-nil.
    # 6. Finally, if we made it here we check if *r* is the string representation of a SignedGlobalID:
    #    call `GlobalID::Locator.locate_signed` to get the object and run the class chaeck if *klass* is non-nil.
    #    If no object, return `nil`.
    #
    # @param r [Integer,String,GlobalID] The reference from which to extract the object identifier.
    # @param klass [Class,String] A class object, or the name of a class object. When this parameter is present,
    #  if class information is available in *r*, it is compared to *klass*.
    #
    # @return [Integer,nil] Returns the integer object identifier; if all checks fail, it returns `nil`.
    
    def self.extract_identifier_from_reference(r, klass = nil)
      if r.respond_to?(:id)
        return check_object_class_and_id(r.class, r.id, klass)
      elsif r.is_a?(Integer) || (r.is_a?(String) && (r =~ /^[0-9]+$/))
        return r.to_i
      elsif r.is_a?(SignedGlobalID) || r.is_a?(GlobalID)
        pre, cname, id = r.uri.path.split('/')
        return check_object_class_and_id(cname, id, klass)
      elsif r.is_a?(String)
        if r =~ /^gid:\/\//
          uri = URI.parse(r)
          pre, cname, id = uri.path.split('/')
          return check_object_class_and_id(cname, id, klass)
        else
          cname, id = ActiveRecord::Base.split_fingerprint(r)
          if id.nil?
            # Unfortunately here we have to get the object
            
            obj = GlobalID::Locator.locate_signed(r)
            return (obj.nil?) ? nil : check_object_class_and_id(obj.class, obj.id, klass)
          else
            return check_object_class_and_id(cname, id, klass)
          end
        end
      end
    end

    # Converts a list of references to a list of object identifiers.
    # This method takes an array containing references to objects of a single class, and returns
    # an array of object identifiers for all the converted references.
    # It reduces *rl*, calling {#extract_identifier_from_reference} for each element; if the return value is
    # non-nil, the identifier is added to the return array.
    #
    # Note that elements that do not match any of the conditions in {#extract_identifier_from_reference}
    # are dropped from the return value.
    #
    # @param rl [Array<Integer,String,ActiveRecord::Base>] The array of references to convert.
    # @param klass [Class,String] The ActiveRecord::Base subclass for the references, or the class name.
    #
    # @return [Array<Integer>] Returns an array of object identifiers.

    def self.convert_list_of_references(rl, klass)
      return nil if rl.nil?
      rl = [ rl ] unless rl.is_a?(Array)
      
      rl.reduce([ ]) do |acc, r|
        id = extract_identifier_from_reference(r, klass)
        acc << id unless id.nil?
        acc
      end
    end

    # Normalize **:only** and **:except** lists or object references in a set of query options.
    # This method looks up the two options **:only** and **:except** in *opts* and
    # converts them using {#convert_list_of_references}. It then generates new values of **:only** and
    # **:except** lists from the converted references as follows.
    #
    #  1. If the **:only** references is empty or not present, the return value does not contain **:only**.
    #  2. If the **:except** references is empty or not present, the return value does not contain **:except**.
    #  3. If both reference arrays are present, both **:only** and **:except** are present; scalar values are
    #     converted to one-element arrays.
    #
    # For example, if *opts* is `{ only: [ 1, 'MyGroup/2', 3, 'Other/4' ], except: [ 2, 4 ] }`, the return
    # value from `normalize_lists_of_references(opts, 'MyGroup')` is
    # `{ only: [ 1, 2, 3 ], except: [ 2, 4 ] }`.
    # If *opts* is `{ only: [ 1, 2, 3, 4 ] }`, the return
    # value from `partition_lists_of_references(opts, 'MyGroup')` is
    # `{ only: [ 1, 2, 3 ] }`.
    # If *opts* is `{ except: [ 2, 4 ] }`, the return
    # value from `partition_lists_of_references(opts, MyGroup)` is
    # `{ except: [ 2, 4 ] }`.
    #
    # @param opts [Hash,ActionController::Parameters] The query options.
    # @param klass [Class,String] The class or class name to pass to {#convert_list_of_references}.
    #
    # @return [Hash] Returns a hash that contains up to two key/value pairs: the **:only** key is the
    #  list of object identifiers to accept, and **:except** the list to reject. If the value of a
    #  key is `nil`, or if the key is missing, the value should be ignored.
    #  Note that, if *opts* is not a hash, `nil` is returned.
    
    def self.normalize_lists_of_references(opts, klass)
      return nil unless opts.is_a?(Hash) || opts.is_a?(ActionController::Parameters)
      
      rv = { }

      if opts.has_key?(:only) && !opts[:only].nil?
        ol = (opts[:only].is_a?(Array)) ? opts[:only] : [ opts[:only] ]
        rv[:only] = convert_list_of_references(ol, klass)
      end

      if opts.has_key?(:except) && !opts[:except].nil?
        xl = (opts[:except].is_a?(Array)) ? opts[:except] : [ opts[:except] ]
        rv[:except] = convert_list_of_references(xl, klass)
      end

      return rv
    end
    
    # Extract a fingerprint from a parameter.
    # The method runs a number of checks until one succeeds:
    #
    # 1. If *r* responds to **:fingerprint**, call that method and return its return value.
    # 2. If *r* is a SignedGlobalID or GlobalID, extract the fingerprint from its URI.
    # 3. If *r* is a string starting with `gid://`, then this is a string representation of a GlobalID: extract
    #    the fingerprint from it.
    # 4. Split *r* as a fingerprint; if both class name and id components are non-nil, this looks like a well formed
    #    fingerprint and we return it.
    # 5. Finally, if we made it here we check if *r* is the string representation of a SignedGlobalID:
    #    call `GlobalID::Locator.locate_signed` to get the object and run the class chaeck if *klass* is non-nil.
    #    If no object, return `nil`.
    #
    # @param r [Integer,String,GlobalID] The reference from which to extract the object identifier.
    #
    # @return [String,nil] Returns the fingerprint; if all checks fail, it returns `nil`.
    
    def self.extract_fingerprint_from_reference(r)
      # On a GlobalID URI, the path contains the location of the object, which by an amazing
      # turn of fate is the same as a fingerprint!

      if r.respond_to?(:fingerprint)
        return r.fingerprint
      elsif r.is_a?(GlobalID) || r.is_a?(SignedGlobalID)
        return r.uri.path.slice(1, r.uri.path.length)
      elsif r.is_a?(String)
        if r =~ /^gid:\/\//
          uri = URI.parse(r)
          return uri.path.slice(1, uri.path.length)
        else
          c, id = ActiveRecord::Base.split_fingerprint(r)
          if !c.nil? && !id.nil?
            # looks like a fingerprint

            return r
          else
            # if we made it here, we need to check if this is a string representation of a shared global id, and
            # unfortunately in this case we have to instantiate the object

            obj = GlobalID::Locator.locate_signed(r)
            return (!obj.nil? && obj.respond_to?(:fingerprint)) ? obj.fingerprint : nil
          end
        end
      end
    end

    # Converts a list of polymorphic references to a list of object fingerprints.
    # This method takes an array containing references to objects of potentially different classes, and
    # returns an array of object fingerprints for all the converted references.
    # It reduces *rl*, calling {.extract_fingerprint_from_reference} for each element; if the return value is
    # non-nil, the identifier is added to the return array.
    #
    # Note that elements that do not match any of these conditions in {.extract_fingerprint_from_reference}
    # are dropped from the return value.
    #
    # @param rl [Array<Integer,String,ActiveRecord::Base>] The array of references to convert.
    #
    # @return [Array<String>] Returns an array of object fingerprints.
    
    def self.convert_list_of_polymorphic_references(rl)
      return nil if rl.nil?
      rl = [ rl ] unless rl.is_a?(Array)
      
      rl.reduce([ ]) do |acc, r|
        fp = extract_fingerprint_from_reference(r)
        acc << fp unless fp.nil?
        acc
      end
    end

    # Normalize **:only** and **:except** lists or polymorphic object references in a set of query options.
    # This method looks up the two options **:only** and **:except** in *opts* and
    # converts them using {#convert_list_of_polymorphic_references}. It then generates new values of **:only** and
    # **:except** lists from the converted references as follows.
    #
    #  1. If the **:only** references is empty or not present, the return value does not contain **:only**.
    #  2. If the **:except** references is empty or not present, the return value does not contain **:except**.
    #  3. If both reference arrays are present, both **:only** and **:except** are present; scalar values are
    #     converted to one-element arrays.
    #
    # @param opts [Hash,ActionController::Parameters] The query options.
    #
    # @return [Hash] Returns a hash that contains up to two key/value pairs: the **only_** key is the
    #  list of object identifiers to accept, and **:except** the list to reject. If the value of the
    #  key is `nil`, or if the key is missing, the value should be ignored.
    #  Note that, if *opts* is not a hash, `nil` is returned.
    
    def self.normalize_lists_of_polymorphic_references(opts)
      return nil unless opts.is_a?(Hash) || opts.is_a?(ActionController::Parameters)
    
      rv = { }

      if opts.has_key?(:only) && !opts[:only].nil?
        ol = (opts[:only].is_a?(Array)) ? opts[:only] : [ opts[:only] ]
        rv[:only] = convert_list_of_polymorphic_references(ol)
      end

      if opts.has_key?(:except) && !opts[:except].nil?
        xl = (opts[:except].is_a?(Array)) ? opts[:except] : [ opts[:except] ]
        rv[:except] = convert_list_of_polymorphic_references(xl)
      end

      return rv
    end

    # Convert a filtered list.
    # This method converts *list* by passing it to the block *b* and returning its return value.
    #
    # @param filter [Fl::Core::Query::Filter] The filter object making the call. This value is passed to the block *b*.
    # @param list [Array] An array of items to be converted by *b*; a scalar value is converted to a one-element
    #  array before passing to the block.
    # @param type [Symbol] A tag passed to the block to provide a hint about the list; this is used by
    #  {.partition_filter_lists} to pass the name of the property being converted.
    # @param b [Proc] The block to call; see below.
    #
    # @yield [filter, list, type] The three arguments are the filter object making the call, the array containing the
    #  list to convert, and the value of *type*.
    #
    # @return [Array, nil] Returns the block value; if *list* is `nil`, returns `nil`.

    def self.convert_filter_list(filter, list, type, &b)
      return nil if list.nil?
      
      list = [ list ] unless list.is_a?(Array)

      return b.call(filter, list, type)
    end

    # Normalize **:only** and **:except** filtered lists in a set of query options.
    # This method looks up the two options **:only** and **:except** in *opts* and
    # converts them using {.convert_filter_list}. It then generates new values of **:only** and
    # **:except** lists from the converted references as follows.
    #
    #  1. If the **:only** references is empty or not present, the return value does not contain **:only**.
    #  2. If the **:except** references is empty or not present, the return value does not contain **:except**.
    #  3. If both reference arrays are present, both **:only** and **:except** are present; scalar values are
    #     converted to one-element arrays.
    #
    # @param filter [Fl::Core::Query::Filter] The filter object making the call. This value is passed to the block *b*.
    # @param opts [Hash,ActionController::Parameters] The query options.
    # @param b [Proc] The block to call; see below.
    #
    # @yield [filter, list, type] The three arguments are the filter object making the call, the array containing the
    #  list to convert, and the value **:only** or **:except** to indicate if this is the `:only` list or the
    #  `:except` one.
    #
    # @return [Hash] Returns a hash that contains up to two key/value pairs: the **:only** key is the
    #  list of object identifiers to accept, and **:except** the list to reject. If the value of a
    #  key is `nil`, or if the key is missing, the value should be ignored.
    #  Note that, if *opts* is not a hash (or ActionController::Parameters), `nil` is returned.
    
    def self.normalize_filter_lists(filter, opts, &b)
      return nil unless opts.is_a?(Hash) || opts.is_a?(ActionController::Parameters)
    
      rv = { }

      if opts.has_key?(:only) && !opts[:only].nil?
        rv[:only] = convert_filter_list(filter, opts[:only], :only) { |f, l, t| b.call(f, l, t) }
      end

      if opts.has_key?(:except) && !opts[:except].nil?
        rv[:except] = convert_filter_list(filter, opts[:except], :except) { |f, l, t| b.call(f, l, t) }
      end

      return rv
    end

    # Adjust **:only** and **:except** lists in a set of query options.
    # This method generates new values of **:only** and
    # **:except** lists from *opts* as follows.
    #
    #  1. If the **:only** array is empty, not present, or `nil`, the return value does not contain **:only**.
    #     The method also converts a scalar non-nil value to a one-element array.
    #  2. If the **:except** array is empty, not present, or `nil`, the return value does not contain  **:except**.
    #     The method also converts a scalar non-nil value to a one-element array.
    #  3. If both arrays are present, remove the contents of the **:except** array from the
    #     **:only** array, and return this new value in **:only**; the return value does not contain **:except**.
    #
    # For example, if *opts* is `{ only: [ 1, 2, 3, 4 ], except: [ 2, 4 ] }`, the return value is
    # `{ only: [ 1, 3 ] }`.
    # If *opts* is `{ only: [ 1, 2, 3, 4 ] }`, the return value is
    # `{ only: [ 1, 2, 3, 4 ] }`.
    # If *opts* is `{ except: [ 2, 4 ] }`, the return value is
    # `{ except: [ 2, 4 ] }`.
    #
    # @param opts [Hash,ActionController::Parameters] The query options.
    #
    # @return [Hash] Returns a hash that contains up to two key/value pairs: the **:only** key is the
    #  list of elements to accept, and **:except** the list to reject. If the value of a
    #  key is `nil`, or if the key is missing, the value should be ignored.
    #  Note that, if *opts* is not a hash, `nil` is returned.
    
    def self.adjust_only_except_lists(opts)
      return nil unless opts.is_a?(Hash) || opts.is_a?(ActionController::Parameters)
      
      rv = { }

      if opts.has_key?(:only) && !opts[:only].nil?
        o = (opts[:only].is_a?(Array)) ? opts[:only] : [ opts[:only] ]
        
        if opts.has_key?(:except) && !opts[:except].nil?
          x = (opts[:except].is_a?(Array)) ? opts[:except] : [ opts[:except] ]
          rv[:only] = o - x
        else
          rv[:only] = o
        end
      elsif opts.has_key?(:except) && !opts[:except].nil?
        rv[:except] = (opts[:except].is_a?(Array)) ? opts[:except] : [ opts[:except] ]
      end

      return rv
    end

    # Parse a timestamp parameter's value.
    # The value *value* is either an integer containing a UNIX timestamp, a Time object, or a string
    # containing a string representation of the time; the value is converted to a
    # {Fl::Core::Icalendar::Datetime} and returned in that format.
    #
    # @param value [Integer, Time, String] The timestamp to parse.
    #
    # @return [Fl::Core::Icalendar::Datetime, String] On success, returns the parsed timestamp.
    #  On failure, returns a string containing an error message from the parser.

    def self.parse_timestamp(value)
      begin
        return Fl::Core::Icalendar::Datetime.new(value)
      rescue => exc
        return exc.message
      end
    end
  end
end
