module Fl::Core::Query
  # A class to manage query filters.
  # The class defines two query management methods: {#generate} and {#adjust}. {#generate} traverses a filter
  # specification hash, using the configuration passed to the initializer to process the hash to generate a
  # WHERE clause and corresponding set of bind parameters.
  #
  # {#adjust} can be used to adjust filter specifications: it also traverses a filter hash, but in this case it
  # executes a client provided block that may modify the value of a node in the hash. This method can be used by
  # clients, for example, to restrict filter specifications to implement access control.
  #
  # ## The filter configuration
  #
  # The configuration hash describes the filters available to a filter context. It contains a key **:filters**,
  # whose value is a hash listing filters by name. Keys are filter names, and values are hashes describing them.
  # These hashes contain the following keys:
  #
  # - **:type** the filter type; see below.
  # - **:field** the name of the column used in the clause.
  # - **:convert** the conversion mechanism.
  # - **:class_name** the class name used by the **:references** type.
  # - **:generator** a Proc used by the **:custom** type to construct a custom WHERE clause.
  #
  # The {#generate} method uses these filter descriptions to generate WHERE clauses from a filter specification.
  #
  # ### Filter details
  #
  # A number of filter types are supported.
  #
  # #### **:references**
  #
  # The **:references** type generates a WHERE clause that filters based on the `IN` operator; it expects a value
  # containing the two keys **:only** and **:except**, which list objects that should be included in, or excluded
  # from, the result set. Specifically:
  #
  # 1. It converts the values of **:only** and **:except** to arrays of identifiers.
  # 2. If **:except** is not present or is an empty array, it generates a WHERE clause where the column name in the
  #    **:field** configuration option is `IN` the **:only** list.
  # 3. If both **:only** and **:except** are present, it removes the members of **:except** from **:only**, and then
  #    proceeds as for step 2.
  # 4. If only **:except** is present, it generates a WHERE clause where the column name in the
  #    **:field** configuration option is `NOT IN` the **:except** list.
  #    Note, however, that if the **:except** list is empty, then no clause is generated: if we except no values,
  #    then all records should be returned.
  #
  # So **:references** applies to columns that contain a single class reference to other objects.
  #
  # #### **:polymorphic_references**
  #
  # The **:polymorphic_references** type behaves like **:references**, except that the contents of **:only**
  # and **:except** are converted to arrays of object fingerprints.
  # So **:polymorphic_references** applies to columns that contain a polymorphic reference to other objects.
  #
  # #### **:block_list**
  #
  # This type behaves similarly to **:references** and **:polymorphic_references**, except that the **:only**
  # and **:except** lists are converted using a custom block from the **:convert** configuration option.
  # This block takes three arguments: *filter* is the {Filter} instance running the {#generate} method,
  # *list* is the array to convert, and *type* is either **:only** or **:except**.
  #
  # The filter generates a WHERE clause just as for **:references** and **:polymorphic_references**, using the
  # `IN`/`NOT IN` operator.
  #
  # #### **:timestamp**
  #
  # This type generates a WHERE clause that selects column values that compare with the filter value provided.
  # The filter value is a hash containing one of these keys:
  #
  # 1. **:at** matches the column to the time value.
  # 2. **:not_at** is the inverse of **:at**.
  # 3. **:after** matches if the column is later than the time value.
  # 4. **:at_or_after** matches if the column is later than, or the same as, the time value.
  # 5. **:before** matches if the column is earlier than the time value.
  # 6. **:at_or_before** matches if the column is before than, or the same as, the time value.
  # 7. **:between** matches if the column is between the two times in the value (which is an array).
  # 8. **:not_between** is the inverse of **:between**.
  #
  # If multiple keys are present, they are looked up in the order listed above. Note that the time value is
  # a single timestamp for all, except for **:between** and **:not_between**, where it is an array of two timestamps.
  #
  # #### **:custom**
  #
  # The **:custom** type lets you define your own clause generator. It executes the block stored in the **:generator**
  # configuration option, and uses the value returned by the block. This block is called with the following arguments:
  #
  # 1. *g* is the filter generator (the instance of {Fl::Core::Query::Filter} running the {#generate} method).
  # 2. *n* is the filter name.
  # 3. *d* is the filter descriptor.
  # 4. *v* is the filter value.
  #
  # The contents of the filter value (*v*) are arbitrary. If the block returns `nil`, no clause is generated.
  #
  # ## The filter specification
  #
  # The filter specification lists the filters to apply to generate a WHERE clause.
  # In addition to the names listed in the **:filters** option of the associated configuration hash,
  # the {#generate} filter processes two special keys that combine filters: **:all** and **:any**.
  # It also processes the special key **:not** to invert the value of a clause.
  # The value for **:all** is a hash containing a list of filters (including **:all** and **:any**); it
  # generates a WHERE clause that joins the filters with the `AND` operator.
  # The value for **:any* is a hash containing a list of filters (including **:all** and **:any**); it
  # generates a WHERE clause that joins the filters with the `OR` operator.
  # The value for **:not** is a filter expression that generates the clause to invert.
  # Note that, since **:all** and **:any** accept **:all** and **:any** keys, you can build a nested structure
  # of filters and associated WHERE clauses.
  #
  # The top level filter specification uses an implicit **:all**; if you want the top level to be a group of
  # `OR` clauses, wrap it in a **:any** filter.
  #
  # Note that multiple filter specifications can be used for the same filter configuration.
  #
  # ## A filter example
  #
  # This is a sample configuration extracted from a test script:
  #
  # ```
  # {
  #   filters: {
  #     ones: {
  #       type: :references,
  #       field: 'c_one',
  #       class_name: 'Fl::Core::TestDatumOne',
  #       convert: :id
  #     },
  #
  #     polys: {
  #       type: :polymorphic_references,
  #       field: 'c_poly',
  #       convert: :fingerprint
  #     },
  #
  #     blocked: {
  #       type: :block_list,
  #       field: 'c_blocked',
  #       convert: Proc.new { |filter, list, type| list.map { |e| e * 10 } }
  #     },
  #
  #     block2: {
  #       type: :block_list,
  #       field: 'c_block2',
  #       convert: Proc.new { |filter, list, type| list.map { |e| e * 2 } }
  #     },
  #
  #     ts1: {
  #       type: :timestamp,
  #       field: 'c_ts1',
  #       convert: :timestamp
  #     },
  #
  #     cstm: {
  #       type: :custom,
  #       field: 'c_custom',
  #       convert: :custom,
  #       generator: Proc.new do |g, n, d, v|
  #         raise Fl::Core::Query::Filter::Exception.new("missing required :foo property in #{v}") if !v[:foo]
  #
  #         p = g.allocate_parameter(v[:foo].downcase)
  #         "(LOWER(#{d[:field]}) = :#{p})"
  #       end
  #     }
  #   }
  # }
  # ```
  #
  # It contains a **:references** filter associated with the `c_one` column, **:polymorphic_references** associated
  # with `c_poly`, two **:block_list** filters associated with **c_blocked` and `c_block2`, a **:timestamp** filter
  # associated with `c_ts1`, and a **:custom** filter associated with `c_custom`.
  #
  # The **:blocked** filter converts input data values by multiplying them by 10; **:block2** multiplies them
  # by 2. There is no requirement that the input and output lists have the same number of elements.
  #
  # The **:cstm** filter generates a WHERE clause that matches the lowercase value of `c_custom` with the
  # lowercase filter value. Note the use of {Fl::Core::Query::Filter#allocate_parameter} to place the lowercase
  # filter value in a bind parameter.
  #
  # ### Using the filter
  #
  # Here are some example of filter specifications and the WHERE clauses they generate.
  # They all use the filter configuration shown above.
  #
  # ```
  # {
  #   all: {
  #     ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
  #     polys: { except: 'Fl::Core::TestDatum/1' },
  #     blocked: { only: [ 1, 2 ], except: [ 1 ] }
  #   }
  # }
  # ```
  #
  # generates
  #
  # ```
  # ((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))
  # ```
  #
  # where the bind parameters have values
  #
  # ```
  # {
  #   p1: [ 1, 2 ],
  #   p2: [ 'Fl::Core::TestDatum/1' ],
  #   p3: [ 20 ]
  # }
  # ```
  #
  # This filter specification uses a top level **:any** to generate `OR` clauses.
  #
  # ```
  # {
  #   any: {
  #     ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
  #     polys: { except: 'Fl::Core::TestDatum/1' },
  #     blocked: { only: [ 1, 2 ], except: [ 1 ] }
  #   }
  # }
  #
  # ((c_one IN (:p1)) OR (c_poly NOT IN (:p2)) OR (c_blocked IN (:p3)))
  #
  # {
  #   p1: [ 1, 2 ],
  #   p2: [ 'Fl::Core::TestDatum/1' ],
  #   p3: [ 20 ]
  # }
  # ```
  #
  # And here is a nested filter specification:
  #
  # ```
  # {
  #   any: {
  #     ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
  #     all: {
  #       polys: { except: 'Fl::Core::TestDatum/1' },
  #       any: {
  #         blocked: { only: [ 1, 2 ], except: [ 1 ] },
  #         block2: { only: [ 3, 5 ] }
  #       }
  #     }
  #   }
  # }
  #
  # ((c_one IN (:p1)) OR ((c_poly NOT IN (:p2)) AND ((c_blocked IN (:p3)) OR (c_block2 IN (:p4)))))
  #
  # {
  #   p1: [ 1, 2 ],
  #   p2: [ 'Fl::Core::TestDatum/1' ],
  #   p3: [ 20 ],
  #   p4: [ 6, 10 ]
  # }
  # ```
  #
  # ## The `adjust` method
  #
  # There are situations where an API might want to adjust the filter request, for example if it comes from an
  # untrusted source, or if it needs to be sanitized to prevent unauthorized access to some resources.
  # The {#adjust} method provides a mechanism to make changes to a filter specification using a block that is
  # executed for each filter node in a filter specification: it implements traversal and filter checking, and
  # calls out to the custom block to make adjustments to the filter.
  #
  # For example, here is a code fragment from a test that uses the filter configuration shown above
  # (`g1` is the filter object). This is a contrived example, but it gives the idea of how one could apply
  # {#adjust}; in this case, the **:ones** filter value is adjusted to a fixed object, **:blocked** removes
  # even numbers, and **:polys** keeps only fingerprints corresponding to the `Fl::Core::TestDatumTwo` class.
  #
  # ```
  # of = {
  #   ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
  #   any: {
  #     blocked: { only: [ 21, 22 ], except: [ 11, 12, 21, 22 ] },
  #     polys: { only: [ 'Fl::Core::TestDatumOne/3', 'Fl::Core::TestDatumTwo/4' ] }
  #   }
  # }
  #
  # nf = g1.adjust(of) do |g, fk, fv| fv
  #   case fk
  #   when :ones
  #     fv.reduce({ }) do |acc, fkvp|
  #       ek, ev = fkvp
  #       acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
  #       acc
  #     end
  #   when :blocked
  #     fv.reduce({ }) do |acc, fkvp|
  #       ek, ev = fkvp
  #       acc[ek] = ev.reduce([ ]) do |acc1, e1|
  #         acc1 << e1 if (e1 % 2) != 0
  #         acc1
  #       end
  #       acc
  #     end
  #   when :polys
  #     fv.reduce({ }) do |acc, fkvp|
  #       ek, ev = fkvp
  #       acc[ek] = ev.reduce([ ]) do |acc1, e1|
  #         acc1 << e1 if e1 =~ /Fl::Core::TestDatumTwo/
  #         acc1
  #       end
  #       acc
  #     end
  #   else
  #     fv
  #   end
  # end
  # ```
  #
  # The value returned by the call to `g1.adjust(of)` is the adjusted filter specification:
  #
  # ```
  # {
  #   ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
  #   any: {
  #     blocked: { only: [ 21 ], except: [ 11, 21 ] },
  #     polys: { only: [ 'Fl::Core::TestDatumTwo/4' ] }
  #   }
  # }
  # ```
  #
  # Compare this to the original:
  #
  # ```
  # {
  #   ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
  #   any: {
  #     blocked: { only: [ 21, 22 ], except: [ 11, 12, 21, 22 ] },
  #     polys: { only: [ 'Fl::Core::TestDatumOne/3', 'Fl::Core::TestDatumTwo/4' ] }
  #   }
  # }
  # ```
  
  class Filter
    # The exception raised by the filter generator.

    class Exception < RuntimeError
    end
    
    # Initializer.
    #
    # @param cfg [Hash] Configuration for the filter.
    #
    # @option cfg [Hash] :clauses A hash of clause descriptions. See the class introduction for details.

    def initialize(cfg = { })
      @config = cfg
      reset()
    end

    # @!attribute config [r]
    # The configuration that was passed to the initializer.
    # @return [Hash] Returns the configuration parameters for the filter.

    attr_reader :config

    # @!attribute counter [r]
    # The current value of the parameter counter.
    # @return [Integer] Returns the current value of the argument counter.

    attr_reader :counter

    # @!attribute clause [r]
    # The WHERE clause generated by a call to {#generte}.
    
    # @!attribute params [r]
    # The parameters for the generated WHERE clause. This is a hash whose values were generated during
    # execution of the {#generate} method, and they contain the values for the bind parameters in the
    # clause.
    # @return [Hash] Returns a hash containing the bind parameters.

    attr_reader :params
    
    # Reset the filter state.
    # This methods sets {#counter} to 0, {#params} to an empty hash, and {#clause} to an empty string.

    def reset
      @counter = 0
      @params = { }
      @clause = ''
    end

    # Allocate a parameter for the WHERE clause.
    # This method reserves a parameter, optionally sets its value, and returns its name.
    #
    # @param value [any] If non-nil, this is the value to be assigned to the parameter. You can use
    #  {#set_parameter} to set its value later.
    #
    # @return [Symbol] Returns the name of the new parameter.
    
    def allocate_parameter(value = nil)
      @counter += 1
      pk = "p#{@counter}".to_sym
      set_parameter(pk, value) unless value.nil?
      return pk
    end

    # Set the value of a parameter for the WHERE clause.
    #
    # @param pk [Symbol] The parameter name.
    # @param value [any] If non-nil, this is the value to be assigned to the parameter.
    
    def set_parameter(pk, value = nil)
      @params[pk] = value unless value.nil?
    end

    # Traverse the filter body and generates an equivalent WHERE clause.
    # If *body* contains nested filters, the method calls itself recursively to generate the multilevel clause.
    # The resulting WHERE clause string is returned, and any parameters the method defines are added to the
    # global {#params}.
    # The current state of the WHERE clause is available as {#clause}, and the corresponding bind values
    # are available in {#params}; after the top-level method call returns, these attributes contain the fully
    # generated WHERE clause and its corresponding parameter set, and can be passed to an ActiveRecord `where`
    # method:
    #
    # ```
    # body = get_filter_body()
    # g = Fl::Core::Query::Generator.new(get_filter_descriptor())
    # g.generate(body)
    # q = MyActiveRecord.where(g.clause, g.params)
    # ```
    #
    # Note that, since this method recurses to generate multi level filters, it does not reset its state; you
    # will have to do that explicitly, by calling {#reset}, when starting afresh. The filter instance starts up
    # in the clean mode, so that creating a new one will automatically start with a clean state.
    #
    # @param body [Hash] The filter body.
    # @param join [Symbol] The operator to use when joining the individual clauses in *body*.
    #
    # @return [String] Returns a string containing the WHERE clause corresponding to *body*.
    #
    # @raise [Exception] Raises an exception if *body* is not a hash, if it contains filters that were not
    #  registered with {#config}, or if a filter type is not supported.

    def generate(body, join = :all)
      return nil if body.nil?
      
      hbody = hash_body(body)

      clauses = hbody.reduce([ ]) do |acc, kvp|
        k, v = kvp
        sk = k.to_sym

        case sk
        when :all, :any
          c = generate(v, sk)
          acc << c unless c.nil?
        when :not
          c = generate(v, sk)
          acc << "(NOT #{c})" unless c.nil?
        else
          c = generate_simple_clause(sk, v)
          acc << c unless c.nil?
        end

        acc
      end

      if clauses.length < 2
        return clauses.first
      else
        case join
        when :all
          return "(#{clauses.join(' AND ')})"
        when :any
          return "(#{clauses.join(' OR ')})"
        else
          return "(#{clauses.join(' AND ')})"
        end
      end
    end

    # Walks the filter descriptor and adjusts it based on a provided block.
    # If *body* contains nested filters, the method calls itself recursively to adjust them.
    #
    # @param body [Hash,ActionController::Parameters] The filter body.
    # @param b [Proc] The block to call; see below.
    #
    # @yield [generator, type, value] The three arguments are: the filter generator (`self`); the name of the filter;
    #  and the value of the filter. The block value replaces the filter value in the specification.

    def adjust(body, &b)
      hbody = begin
                hash_body(body)
              rescue => x
                body
              end
      
      if hbody.is_a?(Hash)
        return body.reduce({ }) do |acc, kvp|
          k, v = kvp
          sk = k.to_sym

          case sk
          when :all, :any, :not
            acc[sk] = adjust(v) { |g, fk, fv| b.call(g, fk, fv) }
          else
            acc[sk] = b.call(self, sk, v)
          end

          acc
        end
      else
        return body
      end
    end

    # Check if a filter body is acceptable.
    # An acceptable filter body is a `Hash` or an `ActionController::Parameters`.
    #
    # @param body [any] The object to check.
    #
    # @return [Boolean] Returns `true` if *body* is acceptable to the filter, `false` otherwise.
    
    def self.acceptable_body?(body)
      return body.is_a?(Hash) || body.is_a?(ActionController::Parameters)
    end
    
    private

    def hash_body(body)
      unless Fl::Core::Query::Filter.acceptable_body?(body)
        raise Exception.new("the filter body is not a hash or hash-like: #{body}")
      end

      return (body.is_a?(ActionController::Parameters)) ? body.to_h : body
    end

    def generate_simple_clause(name, value)
      # this should be a known filter name from the configuration

      raise Exception.new("unknown filter attribute #{name}") unless @config[:filters].has_key?(name)

      desc = @config[:filters][name]
      type = desc[:type]
      case type
      when :references
        ph = Fl::Core::Query::FilterHelper.partition_lists_of_references(value, desc[:class_name])
        if desc[:generator]
          return desc[:generator].call(self, name, desc, ph)
        else
          return generate_partitioned_clause(name, desc, ph)
        end
      when :polymorphic_references
        ph = Fl::Core::Query::FilterHelper.partition_lists_of_polymorphic_references(value)
        if desc[:generator]
          return desc[:generator].call(self, name, desc, ph)
        else
          return generate_partitioned_clause(name, desc, ph)
        end
      when :block_list
        ph = Fl::Core::Query::FilterHelper.partition_filter_lists(self, value) do |f, l, e|
          desc[:convert].call(f, l, e)
        end
        if desc[:generator]
          return desc[:generator].call(self, name, desc, ph)
        else
          return generate_partitioned_clause(name, desc, ph)
        end
      when :timestamp
        if desc[:generator]
          return desc[:generator].call(self, name, desc, value)
        else
          return generate_timestamp_clause(name, desc, value)
        end
      when :custom
        return generate_custom_clause(name, desc, value)
      else
        raise Exception.new("unknown filter type :#{type} for :#{name}")
      end
    end

    public

    # Generates a "partitioned" clause.
    # This method generates a clause from a hash that contains one of two keys: **:only** and **:except**.
    # These two keys were generated from a **:references**, **:polymorphic_references**, or **:block_list**
    # filter type, as described in the class documentation.
    #
    # If **:only** is present, the method generates a WHERE clause for elements `IN` the value of **:only**;
    # If **:except** is present, the method generates a WHERE clause for elements `NOT IN` the value of **:except**;
    # and if neither is present, it returns `nil`.
    #
    # This is the default method called to generate the WHERE clause for one of the three "list" filters; you
    # can override it by providing a **:generator** property in the filter descriptor *desc*, as described in the
    # class documentation.
    #
    # @param name [Symbol] The filter name.
    # @param desc [Hash] The corresponding filter descriptor.
    # @param h [Hash] The value hash; contains the two keys **:only** and **:except**.
    #
    # @return [String, nil] Returns the generated WHERE clause, or `nil` if neither key is present.
    #  Note that, as a side effect, the method allocates a parameter if it generates a clause.
    
    def generate_partitioned_clause(name, desc, h)
      return nil if h.nil?
      
      if h[:only]
        # If we have :only, the :except have already been eliminated, so all we need is the :only

        param = allocate_parameter
        @params[param] = h[:only]
        return "(#{desc[:field]} IN (:#{param}))"
      elsif h[:except]
        # since :only is not present, we need to add the :except.
        # And, if :except is empty or nil, then we don't generate a clause, since filtering by an empty list to
        # except should return all records

        if h[:except].count > 0
          param = allocate_parameter
          @params[param] = h[:except]
          return "(#{desc[:field]} NOT IN (:#{param}))"
        else
          return nil
        end
      else
        return nil
      end
    end

    # The supported **:timestamp** filter keywords.
    
    TIMESTAMP_CONDITIONS = [ :at, :not_at, :after, :at_or_after, :before, :at_or_before, :between, :not_between ]

    # The SQL operators corresponding to the **:timestamp** filter keywords.
    
    TIMESTAMP_OPERATORS = {
      at: '=',
      not_at: '!=',
      after: '>',
      at_or_after: '>=',
      before: '<',
      at_or_before: '<=',
      between: 'BETWEEN',
      not_between: 'NOT BETWEEN'
    }

    # Generates a timestamp clause.
    # This method generates a clause from a hash that contains one of the keys in {TIMESTAMP_CONDITIONS}; the
    # value for most should be a `Time` or Time equivalent corresponding to the time to compare; for
    # **:between** and **:not_between**, it *must* be a two-element array containing the start and end times for
    # the interval.
    #
    # The method tries keys in the order listed in {TIMESTAMP_CONDITIONS}, and returns at the first hit.
    # If no hits, it returns `nil`.
    #
    # This is the default method called to generate the WHERE clause for the **:timestamp** filter; you
    # can override it by providing a **:generator** property in the filter descriptor *desc*, as described in the
    # class documentation.
    #
    # @param name [Symbol] The filter name.
    # @param desc [Hash] The corresponding filter descriptor.
    # @param h [Hash] The value hash; contains at least one of the keys in {TIMESTAMP_CONDITIONS}.
    #
    # @return [String, nil] Returns the generated WHERE clause, or `nil` if no supported key is present.
    #  Note that, as a side effect, the method allocates a parameter if it generates a clause.

    def generate_timestamp_clause(name, desc, value)
      return nil if value.nil?
      
      # The value should contain just one key that describes the condition to match; we check in the given
      # order, so if multiple keys are present, this is the priority in which they are accepted.

      cmp = nil
      op = nil
      t = nil
      
      TIMESTAMP_CONDITIONS.each do |c|
        t = value[c]
        if t
          if ((c == :between) || (c == :not_between)) && (!t.is_a?(Array) || (t.count < 2))
            raise Exception.new("the :between timestamp comparison must have start and end times")
          end
          cmp = c
          op = TIMESTAMP_OPERATORS[c]
          break
        end
      end

      return nil if op.nil?
      
      if (cmp == :between) || (cmp == :not_between)
        start_p = allocate_parameter
        end_p = allocate_parameter
        if t[0] < t[1]
          @params[start_p] = t[0]
          @params[end_p] = t[1]
        else
          @params[start_p] = t[1]
          @params[end_p] = t[0]
        end
        return "(#{desc[:field]} #{op} :#{start_p} AND :#{end_p})"
      else
        param = allocate_parameter
        @params[param] = t
        return "(#{desc[:field]} #{op} :#{param})"
      end
    end

    private
    
    def generate_custom_clause(name, desc, value)
      raise Exception.new("missing :generator property for descriptor in :#{name}") if desc[:generator].nil?

      return nil if value.nil?
      return desc[:generator].call(self, name, desc, value)
    end
  end
end
