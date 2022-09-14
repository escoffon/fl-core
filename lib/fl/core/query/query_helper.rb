module Fl::Core::Query
  # A module that defines a number of support methods for query generation.

  module QueryHelper
    # Parse the **:order** option and return its components.
    # This method processes the **:order** key in *opts* and generates an
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

    def self.parse_order_option(opts, df = nil)
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

      return ord.map { |e| e.strip.gsub(/ +/, ' ') }
    end

    # Parse the **:order** option and generate an ORDER BY clause.
    # This method calls {#_parse_order_option}, and if an order option is found, it generates an appropriate
    # ORDER BY clause.
    # 
    # @param opts [Hash] A hash of query options.
    # @param df [String, Array] The default value for the order option if **:order** is not present
    #  in *opts*. A `nil` value maps to `updated_at DESC'.
    #
    # @option opts [String, Array] :order A string or array containing the <tt>ORDER BY</tt> clauses
    #  to process. The string value is converted to an array by splitting it at commas.
    #  A `false` value or an empty string or array causes the option to be ignored.
    #
    # @return [String] Return a string that may include an ORDER clause.
    #  (If no order clauses are present, it returns an empty string, so that callers can just tag on the
    #  return value without checking.)

    def self.generate_order_clause(opts, df = nil)
      order_clauses = parse_order_option(opts, df)
      return (order_clauses.is_a?(Array)) ? " ORDER BY #{order_clauses.join(', ')}" : ''
    end

    # Parse the **:order** option and add the order clause, if necessary, to a relation.
    # This method calls {#_parse_order_option}, and if a order options are found, it adds them
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

    def self.add_order_clause(q, opts, df = nil)
      order_clauses = parse_order_option(opts, df)
      return (order_clauses.is_a?(Array)) ? q.order(order_clauses) : q
    end
    
    # Check the **:offset** option and generate an OFFSET clause if necessary.
    # This method generates an offset clause if **:offset** is present in *opts*, and it maps to an integer
    # larger than 0. Note that this implies that you can turn off the offset by passing a negative value.
    # 
    # @param opts [Hash] A hash of query options.
    #
    # @option opts [Integer,String] :offset the offset value (zero-based).
    #
    # @return [String] Return a string that may include an OFFSET clause.
    #  (If no offset clause is present, it returns an empty string, so that callers can just tag on the
    #  return value without checking.)

    def self.generate_offset_clause(opts)
      offset = (opts.has_key?(:offset)) ? opts[:offset].to_i : nil
      return (offset.is_a?(Integer) && (offset > 0)) ? " OFFSET #{offset}" : ''
    end
    
    # Check the **:offset** option and add the OFFSET clause, if necessary, to a relation.
    # This method adds an offset clause if **:offset** is present in *opts* and it maps to an integer
    # larger than 0. Note that this implies that you can turn off the offset by passing a negative value.
    # 
    # @param [ActiveRecord::Relation] q The original relation.
    # @param opts [Hash] A hash of query options.
    #
    # @option opts [Integer,String] :offset the offset value (zero-based).
    #
    # @return [ActiveRecord::Relation] Return a relation that may include an OFFSET clause.
    #  If no offset is present, it returns *q*.

    def self.add_offset_clause(q, opts)
      offset = (opts.has_key?(:offset)) ? opts[:offset].to_i : nil
      return (offset.is_a?(Integer) && (offset > 0)) ? q.offset(offset) : q
    end

    # Check the **:limit** option and generate a LIMIT clause if necessary.
    # This method generates a limit clause if **:limit** is present in *opts* and it maps to an integer
    # larger than 0. Note that this implies that you can turn off the limit by passing a negative value.
    # 
    # @param opts [Hash] A hash of query options.
    #
    # @option opts [Integer,String] :limit the limit value.
    #
    # @return [String] Return a string that may include a LIMIT clause.
    #  (If no limit clause is present, it returns an empty string, so that callers can just tag on the
    #  return value without checking.)

    def self.generate_limit_clause(opts)
      limit = (opts.has_key?(:limit)) ? opts[:limit].to_i : nil
      return (limit.is_a?(Integer) && (limit > 0)) ? " LIMIT #{limit}" : ''
    end

    # Check the **:limit** option and add the LIMIT clause, if necessary, to a relation.
    # This method adds a LIMIT clause if **:limit** is present in *opts*, and it map to an integer
    # larger than 0. Note that this implies that you can turn off the limit by passing a negative value.
    # 
    # @param [ActiveRecord::Relation] q The original relation.
    # @param opts [Hash] A hash of query options.
    #
    # @option opts [Integer,String] :limit the limit value.
    #
    # @return [ActiveRecord::Relation] Return a relation that may include a limit clause.
    #  If no offset is present, it returns *q*.

    def self.add_limit_clause(q, opts)
      limit = (opts.has_key?(:limit)) ? opts[:limit].to_i : nil
      return (limit.is_a?(Integer) && (limit > 0)) ? q.limit(limit) : q
    end

    # Process the **:includes** option in a query statement.
    # This method wraps the standard procedure for adding an ActiveRecord `includes` call to the relation *q*.
    #
    # 1. If *includes* is `nil`, use the value in *defaults*.
    # 2. Call {.adjust_includes}, passing the value from 1 and *attachments*; this poterntially triggers eager
    #    loading of an attachment's **:blob** association.
    # 3. If the call returns a hash or a nonempty array, call `includes` on *q*.
    #
    # @param q [Relation] The target relation.
    # @param includes [Array<Symbol>, Hash, Symbol, Boolean, nil] An array of symbols or a hash to pass
    #  to the `includes` method of the relation, the `false` value to disable eager loading, and `nil`
    #  to use the default value.
    #  A single symbol is converted to a one-element array.
    # @param defaults [Array<Symbol>, Hash, false, nil] The default value to use if *includes* is `nil`.
    #  You can pass `false` or `nil` to indicate that, if *includes* is `nil`, no eager loading is to be done.
    # @param attachments [String,Symbol,Array<String,Symbol>] The names of properties in *includes*
    #  that contain ActiveStorage attachments; these properties are converted to a blob association by
    #  {.adjust_includes}. A scalar value is converted to a one element array.
    #  Defaults to `[ :avatar ]`.
    #
    # @return [Relation] Returns the modified relation *q*.

    def self.add_includes(q, includes, defaults = false, attachments = nil)
      includes = defaults if includes.nil?
      inc = Fl::Core::Query::QueryHelper.adjust_includes(includes, attachments)
      case inc
      when Array, Hash
        return (inc.count > 0) ? q.includes(inc) : q
      else
        return q
      end
    end

    # Process a filter specification to generate a WHERE clause.
    # If *filters* is an acceptable filter body, call {Fl::Core::Query::Filter#generate} on *f* and return the
    # generated WHERE clause and associated parameters.
    # If *f* is a hash, the method first instantiates a {Fl::Core::Query::Filter}. This is actually the use for
    # most situations; however, if you need to use a custom filter, you can instantiate it and pass it as the
    # *f* argument.
    #
    # Note that {Fl::Core::Query::Filter#generate} is called with the default top level operand **:all**; if you
    # need OR behavior at the top level, you have to specify **:any** explicitly:
    #
    # ```
    # q = Fl::Core::Query::QueryHelper.process_filters({
    #         any: {
    #           ones: { only: [ 1, 2 ] },
    #           twos: { except: [ 4, 6 ] }
    #         }
    #       }, my_config)
    # ```
    #
    # @param filters [Hash, nil] A hash containing the filters to apply.
    # @param f [Hash, Fl::Core::Query::Filter] The filter to use, or a hash to create a filter automatically.
    #  For most uses, you can pass the configuration hash for the filter, but if you need a custom filter class,
    #  you have the option to instantiate one and pass it along instead.
    #
    # @return [Array] Returns a two-element array containing the WHERE clause and a hash of replacement parameters.
    #  If the first element is `nil`, no clause was generated.

    def self.process_filters(filters, f)
      return [ nil, nil ] unless Fl::Core::Query::Filter.acceptable_body?(filters)
      gen = if f.is_a?(Hash)
              Fl::Core::Query::Filter.new(f)
            elsif f.is_a?(Fl::Core::Query::Filter)
              f
            else
              nil
            end
      if gen.nil?
        return [ nil, nil ]
      else
        clause = gen.generate(filters)
        if !clause.nil? && (clause.length > 0)
          return [ clause, gen.params.dup ]
        else
          return [ nil, nil ]
        end
      end
    end

    # Add filter clauses to an ActiveRecord relation.
    # This method wraps the standard procedure for adding WHERE clauses to a query, based on the *filters*
    # parameter. For a discussion of filters, see {Fl::Core::Query::Filter}.
    #
    # The method calls {.process_filters} to generate a WHERE clause; if the clause value is `false`, a
    # statement is generated that returns no records. If it is `nil`, no WHERE clause is generated.
    # And if it is a valid clause, call the `where` method on *q* to generate a WHERE clause.
    # If *f* is a hash, the method first instantiates a {Fl::Core::Query::Filter}. This is actually the use for
    # most situations; however, if you need to use a custom filter, you can instantiate it and pass it as the
    # *f* argument.
    #
    # Note that {Fl::Core::Query::Filter#generate} is called with the default top level operand **:all**; if you
    # need OR behavior at the top level, you have to specify **:any** explicitly:
    #
    # ```
    # q = Fl::Core::Query::QueryHelper.add_filters(q, {
    #         any: {
    #           ones: { only: [ 1, 2 ] },
    #           twos: { except: [ 4, 6 ] }
    #         }
    #       }, my_config)
    # ```
    #
    # @param q [Relation] The target relation.
    # @param filters [Hash, nil] A hash containing the filters to apply.
    # @param f [Hash, Fl::Core::Query::Filter] The filter to use, or a hash to create a filter automatically.
    #  For most uses, you can pass the configuration hash for the filter, but if you need a custom filter class,
    #  you have the option to instantiate one and pass it along instead.
    #
    # @return [Relation] Returns the modified relation *q*.

    def self.add_filters(q, filters, f)
      clause, filter_params = process_filters(filters, f)
      if !clause.nil?
        if clause == false
          q = q.none
        else
          q = q.where(clause, filter_params)
        end
      end

      return q
    end
    
    # Adjust the **:includes** query parameter.
    # This method iterates over all elements in *includes* and converts any in the *attachments* list to an
    # eager loading directive for the corresponding attachment attribute.
    # If the element is a symbol or string that appears in *attachments*,
    # it is converted to a hash with the appropriate name for the attachment association
    # and the **:blob** nested attachment (in other words, it instructs the query builder to eager load the
    # attachment's **:blob** association).
    # If the element is a hash, each key/value pair is also adjusted recursively for attachment references.
    # Otherwise, the element is left alone.
    #
    # The method also converts an unsupported value for *includes* to an empty array, to indicate that no
    # eager loading should be performed.
    #
    # @param includes [Array<Symbol,String,Hash>,Symbol,String,Hash,false,nil] An array of strings, symbols
    #  or hashes to pass to the `includes` method of the relation.
    #  The method also supports ActionController::Parameters elements.
    #  A single string, symbol or hash is converted to a one-element array.
    #  Any other value, and especially `false` or `nil`, is returned as an empty array to indicate that no
    #  eager loading should be performed.
    # @param attachments [String,Symbol,Array<String,Symbol>] The names of properties in *includes*
    #  that contain ActiveStorage attachments; these properties are converted to a blob association as described
    #  above. A scalar value is converted to a one element array.
    #  Defaults to `nil` (which converts to `[ :avatar ]`).
    #
    # @return [Array] Returns an array of adjusted include descriptors.
    
    def self.adjust_includes(includes, attachments = nil)
      inc = case includes
            when String, Symbol, Hash, ActionController::Parameters
              [ includes ]
            when Array
              includes
            else
              [ ]
            end
      a = (attachments.nil?) ? [ :avatar ] : ((attachments.is_a?(Array)) ? attachments : [ attachments ])
      att = a.map { |e| e.to_sym }
            
      return inc.map do |e|
        case e
        when String, Symbol
          if att.include?(e.to_sym)
            Hash[ "#{e}_attachment".to_sym, [ :blob ] ]
          else
            e
          end
        when Hash
          e.reduce({ }) do |acc, kvp|
            k, v = kvp
            acc[k] = adjust_includes(v, att)
            acc
          end
        when ActionController::Parameters
          e.permit!.to_h.reduce({ }) do |acc, kvp|
            k, v = kvp
            acc[k] = adjust_includes(v, att)
            acc
          end
        else
          e
        end
      end
    end
  end
end
