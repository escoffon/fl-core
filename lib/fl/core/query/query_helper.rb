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

    # Normalize the **:includes** query parameter.
    # The method traverses the *includes* list.
    # If an element is a symbol in **attachments**, or a hash containing a symbol in **attachments**, it is
    # converted to the appropriate name for the attachment association, with the **:blob** nested attachment.
    # For example, the element **:avatar** is converted to `{ avatar_attachment: [ :blob ] }`.
    #
    # As another example, if you know that two associations `commentable` and `author` generate an avatar,
    # a good value for *includes* is `[ { commentable: [ :avatar ] }, { author: [ :avatar ] } ]`.
    #
    # @param includes [Array<Symbol>, Hash, Symbol, false, nil] An array of symbols or a hash to pass
    #  to the `includes` method of the relation, or the `false` value or `nil` to disable eager loading.
    #  A single symbol is converted to a one-element array.
    # @param attachments [String,Symbol,Array<String,Symbol>] The names of properties in *includes*
    #  that contain ActiveStorage attachments; these properties are converted to a blob association by
    #  {.normalize_includes}. A scalar value is converted to a one element array.
    #  Defaults to `[ :avatar ]`.
    #
    # @return [Array,false] Returns an array of include descriptors, or if *includes* is `false`, the
    #  `false` value.
    #  A `false` return value indicates that `includes` should not be called.
  
    def self.normalize_includes(includes, attachments = nil)
      inc = case includes
            when Hash, Array
              includes
            when ActionController::Parameters
              includes.to_h
            when false, nil
              false
            when Symbol
              [ includes ]
            when String
              [ includes.to_sym ]
            else
              false
            end
      return inc unless inc.is_a?(Array) || inc.is_a?(Hash)

      if attachments.nil?
        attachments = [ :avatar ]
      elsif attachments.is_a?(Array)
        attachments = attachments.map { |e| e.to_sym }
      else
        attachments = [ attachments.to_sym ]
      end
      
      return convert_attachment_includes(inc, attachments)
    end

    # Process the **:includes** option in a query statement.
    # This method wraps the standard procedure for adding an ActiveRecord `includes` call to the relation *q*.
    #
    # 1. If *includes* is `nil`, use the value in *defaults*.
    # 2. Call {.normalize_includes}, passing the value from 1 and *attachments*.
    # 3. If the call returns a hash or an array, call `includes` on *q*.
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
    #  {.normalize_includes}. A scalar value is converted to a one element array.
    #  Defaults to `[ :avatar ]`.
    #
    # @return [Relation] Returns the modified relation *q*.

    def self.add_includes(q, includes, defaults = false, attachments = nil)
      includes = defaults if includes.nil?
      inc = Fl::Core::Query::QueryHelper.normalize_includes(includes, attachments)
      return (inc == false) ? q : q.includes(inc)
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
    
    private
    
    def self.convert_attachment_includes(inc, attachments)
      case inc
      when Array
        return inc.map do |e|
          e = e.to_sym if e.is_a?(String)

          case e
          when Symbol
            if attachments.include?(e)
              Hash[ "#{e}_attachment".to_sym, [ :blob ] ]
            else
              e
            end
          when Hash, Array
            convert_attachment_includes(e, attachments)
          else
            e
          end
        end
      when Hash
        return inc.reduce({ }) do |acc, kvp|
          ek, ev = kvp
          sek = ek.to_sym
          sev = (ev.is_a?(String)) ? ev.to_sym : ev
          value = if sev.is_a?(Hash) || sev.is_a?(Array)
                    convert_attachment_includes(ev, attachments)
                  elsif sev.is_a?(Symbol)
                    if attachments.include?(sev)
                      [ Hash[ "#{sev}_attachment".to_sym, [ :blob ] ] ]
                    else
                      [ sev ]
                    end
                  else
                    sev
                  end

          if attachments.include?(sek)
            acc["#{sek}_attachment".to_sym] = value
          else
            acc[sek] = value
          end

          acc
        end
      else
        s = (inc.is_a?(String)) ? inc.to_sym : inc
        return (attachments.include?(s)) ? Hash[ "#{s}_attachment".to_sym, [ :blob ] ] : inc
      end
    end
  end
end
