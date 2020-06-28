module Fl::Core
  # Generic query support.
  # This module defines a number of general support methods used by various query packages.

  module Query
    protected

    # Normalize a boolean query flag.
    # This method accepts a flag value in multiple formats, and converts it to `true` or `false`.
    #
    # @param f [Boolean,Numeric,String,nil] The flag value. If a boolean, it is returned as is.
    #  If a numeric value, it returns `true` if f != 0, and `false` otherwise; therefore, a numeric
    #  value has the same semantics as numeric to boolean conversion in C.
    #  If a string value, and the string is made up wholly of digits, the value is converted to an
    #  integer and processed as for numeric values.
    #  Otherwise, the strings `true`, `t`, `yes`, and `y` are converted to `true`, and `false`, `f`,
    #  `no`, and `n` are converted to `false`. A `nil` value is converted to `false`.
    #  Any other value is also converted to `false`.
    #
    # @return [Boolean] Returns a boolean value as outlined above.
    
    def boolean_query_flag(f)
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
        end
      when NilClass
        false
      else
        false
      end
    end

    # @!visibility private
    def _extract_fingerprint_from_string_reference(acc, r)
      if r =~ /^gid:/i
        # This is a GlobalID URI: the path contains the location of the object, which by an amazing
        # turn of fate is the same as a fingerprint!

        uri = URI.parse(r)
        fp = uri.path.slice(1, uri.path.length)
        c, id = ActiveRecord::Base.split_fingerprint(fp)
        acc << "#{c}/#{id}" unless id.nil?
      else
        c, id = ActiveRecord::Base.split_fingerprint(r)
        acc << "#{c}/#{id}" unless id.nil?
      end
    end

    # @!visibility private
    def _extract_identifier_from_string_reference(acc, r, klass)
      if r =~ /^[0-9]+$/
        acc << r.to_i
      elsif r =~ /^gid:/i
        # This is a GlobalID URI: the path contains the location of the object, which by an amazing
        # turn of fate is the same as a fingerprint!

        uri = URI.parse(r)
        fp = uri.path.slice(1, uri.path.length)
        c, id = ActiveRecord::Base.split_fingerprint(fp, klass)
        acc << id.to_i unless id.nil?
      else
        c, id = ActiveRecord::Base.split_fingerprint(r, klass)
        acc << id.to_i unless id.nil?
      end
    end

    # Converts a list of references to a list of object identifiers.
    # This method takes an array containing references to objects of a single class, and returns
    # an array of object identifiers for all the converted references.
    # The elements of *rl* are one of the following.
    #
    #   - An integer value is assumed to be an object identifier and is added to the return value as is.
    #   - If the value is an instance of *klass*, the return from the value's `id` method is added to
    #     the result.
    #   - If the value is a `GlobalID`, convert it to a string and process it as described below.
    #   - If the value is a String, check if it is an integer representation (it contains just numeric
    #     characters); if so, convert it to an integer and add it to the result.
    #     Otherwise, check if it is a `GlobalID` URI, and if so extract the class name and identifier.
    #     Otherwise, treat it as a fingerprint: call {::ActiveRecord::Base.split_fingerprint}.
    #     If the class name is the same as the name for *klass*, add the identifier.
    #
    # Note that elements that do not match any of these conditions are dropped from the return value.
    #
    # @param rl [Array<Integer,String,ActiveRecord::Base>] The array of references to convert.
    # @param klass [Class] The ActiveRecord::Base subclass for the references.
    #
    # @return [Array<Integer>] Returns an array of object identifiers.

    def convert_list_of_references(rl, klass)
      rl = [ rl ] unless rl.is_a?(Array)
      
      rl.reduce([ ]) do |acc, r|
        if r.is_a?(Integer)
          acc << r
        elsif r.is_a?(klass)
          acc << r.id
        elsif r.is_a?(GlobalID)
          _extract_identifier_from_string_reference(acc, r.to_s, klass)
        elsif r.is_a?(String)
          _extract_identifier_from_string_reference(acc, r, klass)
        end

        acc
      end
    end

    # Converts a list of polymorphic references to a list of object fingerprints.
    # This method takes an array containing references to objects of potentially different classes, and
    # returns an array of object fingerprints for all the converted references.
    # The elements of *rl* are one of the following.
    #
    #   - If the value is an instance of a subclass of `ActiveRecord::Base`, the return from the value's
    #    `fingerprint` method is added to the result.
    #   - If the value is a `GlobalID`, convert it to a string and process it as described below.
    #   - If the value is a String, check if it is an integer representation (it contains just numeric
    #     characters); if so, convert it to an integer and add it to the result.
    #     Otherwise, check if it is a `GlobalID` URI, and if so extract the class name and identifier.
    #     Otherwise, treat it as a fingerprint: call {::ActiveRecord::Base.split_fingerprint}.
    #     If the class name is the same as the name for *klass*, add the identifier.
    #
    # Note that elements that do not match any of these conditions are dropped from the return value.
    #
    # @param rl [Array<Integer,String,ActiveRecord::Base>] The array of references to convert.
    #
    # @return [Array<String>] Returns an array of object fingerprints.
    
    def convert_list_of_polymorphic_references(rl)
      rl = [ rl ] unless rl.is_a?(Array)
      
      rl.reduce([ ]) do |acc, r|
        if r.is_a?(ActiveRecord::Base)
          acc << r.fingerprint if r.respond_to?(:fingerprint)
        elsif r.is_a?(GlobalID)
          _extract_fingerprint_from_string_reference(acc, r.to_s)
        elsif r.is_a?(String)
          _extract_fingerprint_from_string_reference(acc, r)
        end

        acc
      end
    end

    # Partition **only_** and **except_** lists in a set of query options.
    # This method looks up the two options <b>only\_<i>suffix</i></b> and <b>except\_<i>suffix</i></b>
    # in *opts* and
    # converts them using {#convert_list_of_references}. It then generates new values of **only_** and
    # **except_** lists from the converted references as follows.
    #
    #  1. If the **only_** references is empty or not present, the return value contains the references
    #     as is.
    #  2. If the **except_** references is empty or not present, the return value contains the references
    #     as is.
    #  3. If both reference array are present, remove the contents of the **except_** array from the
    #     **only_** array, and return the **only_** array and `nil` for the **except_** array.
    #
    # For example, if *opts* is `{ only_groups: [ 1, 2, 3, 4 ], except_groups: [ 2, 4 ] }`, the return
    # value from `partition_lists_of_references(opts, 'groups', MyGroup)` is
    # `{ only_groups: [ 1, 3 ], except_groups: nil }`.
    # If *opts* is `{ only_groups: [ 1, 2, 3, 4 ] }`, the return
    # value from `partition_lists_of_references(opts, 'groups', MyGroup)` is
    # `{ only_groups: [ 1, 2, 3, 4 ] }`.
    # If *opts* is `{ except_groups: [ 2, 4 ] }`, the return
    # value from `partition_lists_of_references(opts, 'groups', MyGroup)` is
    # `{ except_groups: [ 2, 4 ] }`.
    #
    # @param opts [Hash] The query options.
    # @param suffix [String,Symbol] The suffix for the option names.
    # @param klass [Class] The class to pass to {#convert_list_of_references}.
    #
    # @return [Hash] Returns a hash that contains up to two key/value pairs: the **only_** key is the
    #  list of object identifiers to accept, and **except_** the list to reject. If the value of the
    #  keys is `nil`, or if the key is missing, the value should be ignored.
    
    def partition_lists_of_references(opts, suffix, klass)
      rv = { }

      only_name = "only_#{suffix}".to_sym
      except_name = "except_#{suffix}".to_sym
      
      if opts.has_key?(only_name)
        if opts[only_name].nil?
          rv[only_name] = nil
        else
          only_l = (opts[only_name].is_a?(Array)) ? opts[only_name] : [ opts[only_name] ]
          rv[only_name] = convert_list_of_references(only_l, klass)
        end
      end

      if opts.has_key?(except_name)
        if opts[except_name].nil?
          rv[except_name] = nil
        else
          x_l = (opts[except_name].is_a?(Array)) ? opts[except_name] : [ opts[except_name] ]
          except_refs = convert_list_of_references(x_l, klass)

          # if there is a `only_name`, then we need to remove the `except_name` members from it.
          # otherwise, we return `except_name`

          if rv[only_name].is_a?(Array)
            rv[only_name] = rv[only_name] - except_refs
          else
            rv[except_name] = except_refs
          end
        end
      end

      rv
    end

    # Partition **only_** and **except_** lists in a set of query options.
    # This method looks up the two options <b>only\_<i>suffix</i></b> and <b>except\_<i>suffix</i></b>
    # in *opts* and
    # converts them using the given block. It then generates new values of **only_** and
    # **except_** lists from the converted items as follows.
    #
    #  1. If the **only_** array is empty or not present, the return value contains the array as is.
    #  2. If the **except_** array is empty or not present, the return value contains the array as is.
    #  3. If both arrays are present, remove the contents of the **except_** array from the
    #     **only_** array, and return the **only_** array and `nil` for the **except_** array.
    #
    # @param opts [Hash] The query options.
    # @param suffix [String,Symbol] The suffix for the option names.
    # @yield [list] The array containing the list to convert.
    #
    # @return [Hash] Returns a hash that contains up to two key/value pairs: the **only_** key is the
    #  list of object identifiers to accept, and **except_** the list to reject. If the value of the
    #  keys is `nil`, or if the key is missing, the value should be ignored.
    
    def partition_filter_lists(opts, suffix)
      rv = { }

      only_name = "only_#{suffix}".to_sym
      except_name = "except_#{suffix}".to_sym
      
      if opts.has_key?(only_name)
        if opts[only_name].nil?
          rv[only_name] = nil
        else
          only_l = (opts[only_name].is_a?(Array)) ? opts[only_name] : [ opts[only_name] ]
          rv[only_name] = yield only_l
        end
      end

      if opts.has_key?(except_name)
        if opts[except_name].nil?
          rv[except_name] = nil
        else
          x_l = (opts[except_name].is_a?(Array)) ? opts[except_name] : [ opts[except_name] ]
          except_refs = yield x_l

          # if there is a `only_name`, then we need to remove the `except_name` members from it.
          # otherwise, we return `except_name`

          if rv[only_name].is_a?(Array)
            rv[only_name] = rv[only_name] - except_refs
          else
            rv[except_name] = except_refs
          end
        end
      end

      rv
    end

    # Partition **only_** and **except_** lists in a set of query options, for polymorphic references.
    # This method looks up the two options <b>only\_<i>suffix</i></b> and <b>except\_<i>suffix</i></b>
    # in *opts* and
    # converts them using {#convert_list_of_polymorphic_references}. It then generates new values of
    # **only_** and **except_** lists from the converted references as follows.
    #
    #  1. If the **only_** references is empty or not present, the return value contains the references
    #     as is.
    #  2. If the **except_** references is empty or not present, the return value contains the references
    #     as is.
    #  3. If both reference array are present, remove the contents of the **except_** array from the
    #     **only_** array, and return the **only_** array and `nil` for the **except_** array.
    #
    # @param opts [Hash] The query options.
    # @param suffix [String,Symbol] The suffix for the option names.
    #
    # @return [Hash] Returns a hash that contains up to two key/value pairs: the **only_** key is the
    #  list of object identifiers to accept, and **except_** the list to reject. If the value of the
    #  keys is `nil`, or if the key is missing, the value should be ignored.
    
    def partition_lists_of_polymorphic_references(opts, suffix)
      rv = { }

      only_name = "only_#{suffix}".to_sym
      except_name = "except_#{suffix}".to_sym
      
      if opts.has_key?(only_name)
        if opts[only_name].nil?
          rv[only_name] = nil
        else
          only_l = (opts[only_name].is_a?(Array)) ? opts[only_name] : [ opts[only_name] ]
          rv[only_name] = convert_list_of_polymorphic_references(only_l)
        end
      end

      if opts.has_key?(except_name)
        if opts[except_name].nil?
          rv[except_name] = nil
        else
          x_l = (opts[except_name].is_a?(Array)) ? opts[except_name] : [ opts[except_name] ]
          except_refs = convert_list_of_polymorphic_references(x_l)

          # if there is a `only_name`, then we need to remove the `except_name` members from it.
          # otherwise, we return `except_name`

          if rv[only_name].is_a?(Array)
            rv[only_name] = rv[only_name] - except_refs
          else
            rv[except_name] = except_refs
          end
        end
      end

      rv
    end

    # Generate actor lists from query options.
    # This method builds two lists, one that contains the fingerprints of actors to return
    # in the query, and one of actors to ignore in the query.
    #
    # The method expects the objects in the group lists to respond to the +members+ method, which returns
    # the list of group members.
    #
    # Note that the names of the inclusion and exception lists for actors are configurable; for example, to
    # normalize lists of authors, the caller may pass two options, **:only_authors** and **:except_authors**,
    # whereas to normalize a list of owners, the two options may be **:only_owners** and **:except_owners**.
    # The normalization strategy is independent of the semantics of those two properties, but is very much
    # aware of the semantics of the **:only_goups** and **:except_groups** options.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Object, String>, Object, String] :only_<key> If given, include only the given actor or,
    #  if the value is an array, actors; note that the option name depends on the value of the *key* parameter.
    #  The values are either objects, or strings containing the object's fingerprint
    #  (see {::ActiveRecord::Base#fingerprint}).
    #  If an actor is listed in both **:only_<key>** and **:except_<key>**, it is removed
    #  from *:only_<key>* before the final list is generated; therefore, *:except_<key>*
    #  has higher priority than *:only_<key>*.
    # @option opts [Array<Object, String>, Object, String] :except_<key> If given, do not include the given actor or,
    #  if the value is an array, actors; note that the option name depends on the value of the *key* parameter.
    #  See the documentation for *:only_<key>*.
    # @option opts [Array<Object, String>, Object, String] :only_groups If present, an array of group
    #  objects (or fingerprints) that contains the list used
    #  to limit the returned values to members of the groups. A single value
    #  is converted to an array. Note that the groups are converted to an array of actor fingerprints,
    #  for all the actors in the groups, and that list is added to the final value. (The list may be then trimmed
    #  out based on the actor exclusion list.)
    #  Therefore, this has a similar effect to the *:only_<key>* option.
    #  If both expanded **:only_groups** and **:except_groups** values contain the same actor id, that
    #  actor is dropped from the expanded **:only_groups** list; therefore, **:except_groups** has higher
    #  precedence than **:only_groups**.
    # @option opts [Array<Object, String>, Object, String] :except_groups If given, do not include actors that
    #  are members of the group or,
    #  if the value is an array, groups. See the documentation for **:only_groups**.
    #  The **:except_groups** option expands to a list of object identifiers for actors that should be excluded;
    #  therefore, **:except_groups** acts like *:except_<key>*.
    # @param key [Symbol, String] This value is used to generate the names of the actor options.
    #  For example, if the value of *prefix* is `authors`, then the method looks up the two options **:only_authors**
    #  and **:except_authors**.
    #
    # @return [Hash] Returns a hash with two entries:
    #  - **:only_ids** is +nil+, to indicate that no "must-have" actor selection is requested; or it is
    #    an array whose elements are actors' fingerprints.
    #  - **:except_ids** is +nil+, to indicate that no "must-not-have" actor selection is requested; or it is
    #    an array whose elements are actors' fingerprints.

    def _expand_actor_lists(opts, key = :actors)
      only_key = "only_#{key}".to_sym
      except_key = "except_#{key}".to_sym

      only_actors = opts[only_key]
      only_groups = opts[:only_groups]
      except_actors = opts[except_key]
      except_groups = opts[:except_groups]

      return {
        :only_ids => nil,
        :except_ids => nil
      } if only_actors.nil? && only_groups.nil? && except_actors.nil? && except_groups.nil?

      # 1. Build the arrays of object identifiers

      only_uids = (only_actors.nil?) ? nil : convert_list_of_polymorphic_references(only_actors)
      if only_groups
        t = (only_groups.is_a?(Array)) ? only_groups : [ only_groups ]
        glist = t.map { |g| (g.is_a?(String)) ? ActiveRecord::Base.find_by_fingerprint(g) : g }

        only_gids = []
        glist.each do |g|
          if g && g.respond_to?(:members)
            g.members.each do |u|
              f = u.fingerprint
              only_gids << f unless only_gids.include?(f)
            end
          end
        end
      else
        only_gids = nil
      end

      except_uids = (except_actors.nil?) ? nil : convert_list_of_polymorphic_references(except_actors)
      if except_groups
        t = (except_groups.is_a?(Array)) ? except_groups : [ except_groups ]
        glist = t.map { |g| (g.is_a?(String)) ? ActiveRecord::Base.find_by_fingerprint(g) : g }

        except_gids = []
        glist.each do |g|
          if g && g.respond_to?(:members)
            g.members.each do |u|
              f = u.fingerprint
              except_gids << f unless except_gids.include?(f)
            end
          end
        end
      else
        except_gids = nil
      end

      # 2. The list of actor ids is the union of the groups/actors arrays

      only_ids = (only_uids.nil?) ? nil : only_uids
      unless only_gids.nil?
        if only_ids.nil?
          only_ids = only_gids 
        else
          only_ids |= only_gids 
        end
      end
      except_ids = (except_uids.nil?) ? nil : except_uids
      unless except_gids.nil?
        if except_ids.nil?
          except_ids = except_gids
        else
          except_ids |= except_gids
        end
      end

      # 3. Remove any except ids from the only list

      only_ids = only_ids - except_ids if only_ids.is_a?(Array) && except_ids.is_a?(Array)

      {
        :only_ids => only_ids,
        :except_ids => except_ids
      }
    end

    # Partition actor lists.
    # Calls {#_partition_one_actor_list} for each entry in _hlist_, and returns their partitioned values.
    #
    # @param [Hash] hlist A hash containing actor lists.
    # @option hlist [Array<String>] :only_ids The fingerprints of the objects to place in the "must-have"
    #  clauses. Could be +nil+ if no "must-have" objects were requested.
    # @option hlist [Array<String>] :except_ids The fingerprints of the objects to place in the "must-not-have"
    #  clauses. Could be +nil+ if no "must-have" objects were requested.
    #
    # @return [Hash] Returns a hash containing two entries, **:only_ids** and **:except_ids**, generated as
    #  described above.

    def _partition_actor_lists(hlist)
      h = { }

      if hlist.has_key?(:only_ids) && hlist[:only_ids]
        h[:only_ids] = _partition_one_actor_list(hlist[:only_ids])
      else
        h[:only_ids] = nil
      end

      if hlist.has_key?(:except_ids) && hlist[:except_ids]
        h[:except_ids] = _partition_one_actor_list(hlist[:except_ids])
      else
        h[:except_ids] = nil
      end

      h
    end

    # Partition a list of actors.
    # This method groups all actors whose fingerprints use the same class name, and places in the
    # return value an entry whose key is the class name, and whose value is an array of object identifiers
    # as extracted from the fingerprints.
    # This is how WHERE clauses will be set up.
    #
    # @param [Array<String>] clist An array of object fingerprints. A +nil+ value causes a +nil+ return value.
    #
    # @return [Hash] Returns a hash whose keys are the distinct class names from the fingerprints, and
    #  values the corresponding object identifiers. If _clist_ is +nil+, it returns +nil+.
    #  Note that the object identifiers are returned as strings, and for some ORMs (Active Record comes to
    #  mind...), they will likely have to be converted to integers in order to be used in WHERE clauses.
    
    def _partition_one_actor_list(clist)
      return nil if clist.nil?

      h = { }
      clist.each do |f|
        if f
          cname, id = f.split('/')
          if h.has_key?(cname)
            h[cname] << id
          else
            h[cname] = [ id ]
          end
        end
      end

      h
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

    def _parse_timestamp(value)
      begin
        return Fl::Core::Icalendar::Datetime.new(value)
      rescue => exc
        return exc.message
      end
    end

    # Sets up the parameters for time-related filters.
    # For each of the options listed below, the method places a corresponding entry in the return value
    # containing the timestamp generated from the entry.
    #
    # All parameters are either an integer containing a UNIX timestamp, a Time object, or a string
    # containing a string representation of the time; the value is converted to a
    # {Fl::Core::Icalendar::Datetime} and stored in that format.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Integer, Time, String] :updated_after to select comments updated after a given time.
    # @option opts [Integer, Time, String] :created_after to select comments created after a given time.
    # @option opts [Integer, Time, String] :updated_before to select comments updated before a given time.
    # @option opts [Integer, Time, String] :created_before to select comments created before a given time.
    #
    # @return [Hash] Returns a hash containing any number of the following keys; all values are `TimeWithZone`
    #  instances.
    #
    #  - **:c_after_ts** from **:created_after**.
    #  - **:c_before_ts** from **:created_before**.
    #  - **:u_after_ts** from **:updated_after**.
    #  - **:u_before_ts** from **:updated_before**.

    def _date_filter_timestamps(opts)
      rv = {}

      if opts.has_key?(:created_after)
        begin
          dt = Fl::Core::Icalendar::Datetime.new(opts[:created_after])
          rv[:c_after_ts] = dt.to_time if dt.valid?
        rescue => exc
        end
      end

      if opts.has_key?(:updated_after)
        begin
          dt = Fl::Core::Icalendar::Datetime.new(opts[:updated_after])
          rv[:u_after_ts] = dt.to_time if dt.valid?
        rescue => exc
        end
      end

      if opts.has_key?(:created_before)
        begin
          dt = Fl::Core::Icalendar::Datetime.new(opts[:created_before])
          rv[:c_before_ts] = dt.to_time if dt.valid?
        rescue => exc
        end
      end

      if opts.has_key?(:updated_before)
        begin
          dt = Fl::Core::Icalendar::Datetime.new(opts[:updated_before])
          rv[:u_before_ts] = dt.to_time if dt.valid?
        rescue => exc
        end
      end

      rv
    end

    # Add WHERE clauses for the standard timestamp filters.
    # This method first calls {#_date_filter_timestamps} to generate timestamp filter parameters.
    # If any are found, it adds them to the WHERE clauses and returns the new relation object.
    #
    # Note that any WHERE clauses from **:updated_after**, **:created_after**, **:updated_before**,
    # and **:created_before** are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Integer, Time, String] :updated_after to select objects updated after a given time.
    # @option opts [Integer, Time, String] :created_after to select objects created after a given time.
    # @option opts [Integer, Time, String] :updated_before to select objects updated before a given time.
    # @option opts [Integer, Time, String] :created_before to select objects created before a given time.
    #
    # @return [ActiveRecord::Relation] Return a relation that may include WHERE clauses for timestamp filters.
    #  If no such WHERE clauses are present, it returns *q*.

    def _add_date_filter_clauses(q, opts)
      # We need to convert the timestamps to UTC, or the WHERE clauses (at least on Postgres) are off by
      # the timezone offset
      
      ts = _date_filter_timestamps(opts)
      wt = []
      wta = {}
      if ts[:c_after_ts]
        wt << '(created_at > :c_after_ts)'
        wta[:c_after_ts] = ts[:c_after_ts]
      end
      if ts[:u_after_ts]
        wt << '(updated_at > :u_after_ts)'
#        wta[:u_after_ts] = Time.parse(ts[:u_after_ts].to_rfc3339).utc.rfc3339
        wta[:u_after_ts] = ts[:u_after_ts]
      end
      if ts[:c_before_ts]
        wt << '(created_at < :c_before_ts)'
        wta[:c_before_ts] = ts[:c_before_ts]
      end
      if ts[:u_before_ts]
        wt << '(updated_at < :u_before_ts)'
        wta[:u_before_ts] = ts[:u_before_ts]
      end

      (wt.count > 0) ? q.where(wt.join(' AND '), wta) : q
    end
    
    # Parse the **:order** option and generate an order clause.
    # This method processes the **:order** key in _opts_ and generates an
    # array of converted order clauses.
    # 
    # @param opts [Hash] A hash of query options.
    # @param df [String, Array] The default value for the order option if **:order** is not present
    #  in *opts*. A `nil` value maps to `updated_at DESC'.
    #
    # @option opts [String, Array] :order A string or array containing the <tt>ORDER BY</tt> clauses
    #  to process. The string value is converted to an array by splitting it at commas.
    #  A `false` value or an empty string or array causes the option to be ignored.
    #
    # @return [Array] Returns an array of converted order clauses.

    def _parse_order_option(opts, df = nil)
      ord = case opts[:order]
            when String
              opts[:order].split(/,\s*/)
            when Array
              opts[:order]
            when FalseClass
              nil
            else
              if df.is_a?(Array)
                df
              elsif df.is_a?(String)
                df.split(/,\s*/)
              else
                [ 'updated_at DESC' ]
              end
            end
      return nil if ord.nil? or (ord.count < 1)

      ord.map { |e| e.strip }
    end
    
    # Parse the **:order** option and add the order clause if necessary.
    # This method calls {#_parse_order_option}, and if an order option is found, it adds it
    # to the relation *q*.
    # 
    # @param [ActiveRecord::Relation] q The original relation.
    # @param opts [Hash] A hash of query options.
    # @param df [String, Array] The default value for the order option if **:order** is not present
    #  in *opts*. A `nil` value maps to `updated_at DESC'.
    #
    # @option opts [String, Array] :order A string or array containing the <tt>ORDER BY</tt> clauses
    #  to process. The string value is converted to an array by splitting it at commas.
    #  A `false` value or an empty string or array causes the option to be ignored.
    #
    # @return [ActiveRecord::Relation] Return a relation that may include an ORDER clause.
    #  If no order clauses are present, it returns *q*.

    def _add_order_clause(q, opts, df = nil)
      order_clauses = _parse_order_option(opts)
      (order_clauses.is_a?(Array)) ? q.order(order_clauses) : q
    end
    
    # Check the **:offset** option and add the OFFSET clause if necessary.
    # This method adds an offset clause if **:offset** is present in *opts*, and it map to an integer
    # larger than 0. Note that this implies that you can turn off the offset by passing a negative value.
    # 
    # @param [ActiveRecord::Relation] q The original relation.
    # @param opts [Hash] A hash of query options.
    #
    # @option opts [Integer,String] :offset the offset value (zero-based).
    #
    # @return [ActiveRecord::Relation] Return a relation that may include an OFFSET clause.
    #  If no oofset is present, it returns *q*.

    def _add_offset_clause(q, opts)
      offset = (opts.has_key?(:offset)) ? opts[:offset].to_i : nil
      (offset.is_a?(Integer) && (offset > 0)) ? q.offset(offset) : q
    end
    
    # Check the **:limit** option and add the LIMIT clause if necessary.
    # This method adds an limit clause if **:limit** is present in *opts*, and it map to an integer
    # larger than 0. Note that this implies that you can turn off the limit by passing a negative value.
    # 
    # @param [ActiveRecord::Relation] q The original relation.
    # @param opts [Hash] A hash of query options.
    #
    # @option opts [Integer,String] :limit the limit value.
    #
    # @return [ActiveRecord::Relation] Return a relation that may include an LIMIT clause.
    #  If no oofset is present, it returns *q*.

    def _add_limit_clause(q, opts)
      limit = (opts.has_key?(:limit)) ? opts[:limit].to_i : nil
      (limit.is_a?(Integer) && (limit > 0)) ? q.limit(limit) : q
    end
  end
end
