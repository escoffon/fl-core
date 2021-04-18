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
  end
end
