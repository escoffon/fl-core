# Utility methods for building and executing text searches.
# Mostly covers Postgres-specific functionality.
#
# Use this concern as a mixin module:
#
# ```
# class MyModel < ActiveRecord::Base
#   include Fl::Core::TextSearch::Helper
# end
# ```
  
module Fl::Core::TextSearch::Helper
  extend ActiveSupport::Concern
  
  # The prefix that marks a Postgres `tsquery` string.

  PG_QUERY_STRING_PREFIX = 'pg:'

  # @!method pg_headline_select_item(doc_name, query, attr_name = nil, config_name = nil, opts = nil)
  #   @!scope class
  #   Build the select list item for a "headline" pseudoattribute.
  #
  #   @param doc_name [String] The name of the document (column in our case) that holds the contents
  #    for which to generate a headline.
  #   @param query [String] The query string to use. It is converted to a tsquery via a call to
  #    {.pg_query_string}.
  #   @param attr_name [String] The name of the "headline" pseudoattribute.
  #   @param config_name [String] The name of the column (or the string value in quotes) that holds the
  #    configuration parameters for the text search. If `nil`, no configuration argument is emitted.
  #    Note that this value is emitted as-is and therefore it is interpreted as a column name; to load
  #    it as string constant, include signle quotes in the name.
  #   @param opts [Hash] A hash of options to pass to the `ts_headline` function.
  #    See the Postgres documentation (for example,
  #    {https://www.postgresql.org/docs/9.6/static/textsearch-controls.html here}) for a description
  #    of the possible values. The hash is converted into a string containing the options in the
  #    format that `ts_highlight` expects.
  #
  #   @return [String] Returns a string containing an item that can be added to a select list.

  # @!method strip_select_list(strip = [ 'headline' ])
  #   @!scope class
  #   Strip elements from a select list.
  #   This method builds a select list from the attribute names, and removes the ones listed in *strip*.
  #
  #   @param strip [String, Array<String>] The names of the attributes to remove from the select list.
  #    A string (scalar) value is converted to a one-element array.
  #
  #   @return [Array<String>] Returns an array containing the attribute names from the class, minus
  #    the ones listed in *strip*.

  # @!method tokenize_query_string(qs)
  #   @!scope class
  #   Tokenize a query string.
  #   This method iterates over the contents of *qs*, breaking them up in tokens according to the
  #   text query rules. These tokens are of four types:
  #
  #   1. Operators; these are special values that indicate an operation:
  #
  #       - The string 'OR' (we allow for 'or' to be a bit lenient).
  #          We also allow the string '|' to stand for 'OR', so that the Postgres-style operator name is
  #          also supported.
  #       - The string 'AND' (we allow for 'and' to be a bit lenient).
  #         We also allow the string '&' to stand for 'AND', so that the Postgres-style operator name is
  #         also supported.
  #         This operator is not really needed, because any words not connected by an operator are connected by '&'.
  #       - The string 'AROUND(n)' (we allow for 'around(n)' to be a bit lenient).
  #         Here `n` is an integer to indicate the distance between the two operands.
  #       - The string '-'. Note that '-' not preceded by whitespace is not considered an operator, but
  #         rather part of the preceding token; therefore, `my-tag` is parsed as the single token `my-tag`,
  #         whereas `my -tag` is parsed as the three tokens 'my', '-', and 'tag'.
  #
  #   2. Words; these are collections of characters that drive the matches.
  #   3. Quoted strings; collections of words to be matched as a unit.
  #   4. Grouping: the strings '(' and ')' to control operator precedence.
  #
  #   This text query string has the same format as the one used by Google.
  #
  #   @param qs [String] A string containing characters and operators.
  #
  #   @return [Array<Array>] Returns an array of tokens; the elements are two-element arrays where
  #    the first element is the token type, and the second the token value (if any).
  #    The token types are:
  #
  #    - **:quoted** A quoted string (which typically contains spaces); the value is the quoted string.
  #    - **:word** A word; the value is the word.
  #    - **:minus** The '-' operator.
  #    - **:and** The 'AND' operator.
  #    - **:or** The 'OR' operator.
  #    - **:around** The 'AROUND(n)' operator; the value is the integer value of `n`.
  #    - **:open** The open paren.
  #    - **:close** The close paren.
  #
  #   @raise [MalformedQuery] Raises this exception if the tokenizer detects a malformed query string.

  # @!method pg_query_text(tokens)
  #   @!scope class
  #   Generate a Postgres text search query string from a tokenized sequence.
  #   This method takes the output from {.tokenize_query_string} and builds a string
  #   containing a query text suitable for passing to the Postgres `to_tsquery` function.
  #
  #   @param tokens [Array<Array>] An array of tokens. See {.tokenize_query_string}.
  #
  #   @return [String] Returns a string containing the query text, prefixed by 'pg:'.
  #    For example, the token sequence [ [:token, 'one'], [:token, 'two'] ] is converted to
  #    "pg:one & two". The 'pg:' marker is used by other function to distinguish between raw and
  #    processed query strings.

  # @!method pg_query_string(qs)
  # @!scope class
  #   Convert a query text to a format suitable for use as a Postgres `tsquery`.
  #    If *qs* starts with the sequence 'pg:', it is assumed to be already in `tsquery` format
  #    and is returned as is (except that the 'pg:' prefix is stripped).
  #    Otherwise, the method calls 
  #    {.tokenize_query_string} and {.generate_query_text} to convert it to a query string
  #    for the `to_tsquery` Postgres function.
  #
  #   @param qs [String] A string containing characters and operators.
  #
  #   @return [String] Returns a string suitable to use in `to_tsquery`.

  # @!method pg_parse_order_option(opts, pgqs = nil)
  #   @!scope class
  #   Parse the **:order** option and generate an order clause that includes text query components.
  #   This method processes the **:order** and, optionally, **:rank** keys in *opts* and generates an
  #   array of converted order clauses.
  # 
  #   @param opts [Hash] A hash of query options.
  #   @option opts [String, Array] :order A string or array containing the `ORDER BY` clauses
  #    to process. The string value is converted to an array by splitting it at commas.
  #    A `false` value or an empty string or array causes the option to be ignored.
  #    If the option contains the term **rank**, the method adds a clause that orders the results by
  #    text search score; in that case, the **:rank** option controls the behavior of this clause,
  #    as described below.
  #    Defaults to `updated_at DESC`, so that the results are ordered by modification time, 
  #    with the most recent one listed first.
  #   @option opts [Hash, String] :rank The options to use for the **rank** ORDER BY clause.
  #    If the **:order** option contains the term **rank**, this is the set of options that control the
  #    behavior of the scoring algorithm.
  #    A string value is is assumed to contain a JSON representation of the options and is parsed into
  #    a hash value;
  #    this is provided to support APIs that generate JSON represantions of submission parameters.
  #    The hash value is passed to {.pg_rank} to generate the
  #    appropriate call to the ranking function; see that documentation for a description of the
  #    contents of this hash. Note that, in addition to the options in {.pg_rank},
  #    the **tsv** option is used to set the name of the tsvector column as described below.
  #    Any other value is converted to an empty hash.
  #    The default is an empty hash.
  #   @option opts[:rank] [String] :tsv The name of the column that contains the tsvector to use.
  #    If there is no tsvector column, you can pass "to_tsvector(<document>)" where <document>
  #    is the name of the document column; in this case, the rank function will convert the contents
  #    to a tsvector on the fly.
  #    This option defaults to `tsv`, which is most likely incorrect; in the vast majority of the cases,
  #    the caller will have to provide a value for the option.
  #   @param pgqs [String] A Postgres query string as returned by a call to {.pg_query_string}.
  #
  #   @return [Array] Returns an array containing two elements:
  #
  #    0. An array of converted order clauses.
  #    1. If one of these clauses is **rank**, a string containing the call to the Postgres ranking
  #     function. This value needs to be added to the `SELECT` list of the query.

  # @!method pg_where(doc_name, tsv, qs, cfg = nil)
  #   @!scope class
  #   Build a WHERE clause for a Postgres query.
  #
  #   @param doc_name [String] The name of the document (column in our case) that holds the contents
  #    to search. If you provide a tsvector name in *tsv*, this value is ignored. This is useful in
  #    situations where the document is actually generated from a collection of fields; in this case,
  #    build a tsvector and use that instead of the document field.
  #    You can pass `nil` if you provide a non-nil value to *tsv*.
  #   @param tsv [String] The name of the column that contains the tsvector to use.
  #    This value is placed in the WHERE clause.
  #    If there is no tsvector column, you can pass `nil` and the method will use the
  #    output of "to_tsvector(#{doc_name})" (in other words, it will convert the contents to a tsvector
  #    on the fly).
  #   @param qs [String] The query string to use. If *qs* starts with 'pg:', the method assumes that
  #    the rest of the value has already been converted to Postgres form; otherwise, the method calls
  #    {.tokenize_query_string} and {.generate_query_text} to convert it to a query string
  #    for the `to_tsquery` Postgres function.
  #   @param cfg [String] The name of the configuration to use in the call to `to_tsquery`.
  #    If the value is `nil`, this parameter is not passed to `to_tsquery`; if it does not start
  #    with 'pg_catalog`, that value is added to the parameter.
  # 
  #   @return [String] Returns a string that can be passed to the `where` method in the ActiveRecord
  #    query interface.
  
  # @!method add_full_text_query(q, doc_name, tsv, qs, opts = {})
  #   @!scope class
  #   Modify an ActiveRecord::Relation object to trigger a full text query.
  #   This method adds one or two calls to *q*:
  #
  #   1. An optional `select` if **:with_headline** is enabled, to build the select list for the query.
  #   2. A `where` method containing the text query condition.
  #
  #   @param q [ActiveRecord::Relation] The relation object to modify; if `nil`, uses **self**.
  #   @param doc_name [String] The name of the document (column in our case) that holds the contents
  #    to search. If you provide a tsvector name in *tsv*, this value is ignored. This is useful in
  #    situations where the document is actually generated from a collection of fields; in this case,
  #    build a tsvector and use that instead of the document field.
  #   @param tsv [String] The name of the column that contains the tsvector to use.
  #    This value is placed in the WHERE clause.
  #    If there is no tsvector column, you can pass `nil` and the method will use the
  #    output of "to_tsvector(#{doc_name})" (in other words, it will convert the contents to a tsvector
  #    on the fly).
  #   @param qs [String] The query string to use. If *qs* starts with 'pg:', the method assumes that
  #    the rest of the value has already been converted to Postgres form; otherwise, the method calls
  #    {.tokenize_query_string} and {.generate_query_text} to convert it to a query string
  #    for the `to_tsquery` Postgres function.
  #   @param opts [Hash] Options for the query.
  #   @option opts [String] :with_headline Return a "headline" pseudoattribute if present and
  #    non-false. If the vaue is a string, it is the name of the attribute; if `true`, the name
  #    defaults to **:headline**.
  #   @option opts [String] :with_configuration The name of the configuration to use in the call to
  #    `to_tsquery`.
  #    If the value is `nil`, this parameter is not passed to `to_tsquery`; if it does not start
  #    with 'pg_catalog`, that value is added to the parameter.
  # 
  #   @return [ActiveRecord::Relation] Returns a relation object that has been modified to include a
  #    full text query WHERE condition, and a SELECT condition if a "headline" is desired.

  # @!method pg_rank(tsv, qs, opts = {})
  #   @!scope class
  #   Build a rank expression.
  #   This method generates a string containing a call to a ranking function; this value can then
  #   be used in a select list, or in an ORDER BY clause.
  #
  #   Note that the built-in ranking functions only make sense when the query in *qs* contains
  #   "positive" search terms
  #   (terms that look for the presence of a word). If only "negative" terms are present, then the
  #   score for all results will be 0. For example, the query '-soap' will find documents that do
  #   *not* contain the word `soap`; the score for all those document will be 0, since there are no
  #   matched terms.
  #
  #   @param tsv [String] The name of the column that contains the tsvector to use.
  #    If there is no tsvector column, you can pass "to_tsvector(<document>)" where <document>
  #    is the name of the document column; in this case, the rank function will convert the contents
  #    to a tsvector on the fly.
  #   @param qs [String] The query string to use. If *qs* starts with 'pg:', the method assumes that
  #    the rest of the value has already been converted to Postgres form; otherwise, the method calls
  #    {.tokenize_query_string} and {.generate_query_text} to convert it to a query string
  #    for the `to_tsquery` Postgres function.
  #   @param opts [Hash] Options for the ranking function.
  #   @option opts [String, Symbol] :_f The name of the ranking function to use. Currently supported values
  #    are the two Postgres default `ts_rank` and `ts_rank_cd`; the default value is `ts_rank`.
  #   @option opts [Hash] :_w The weights to associate with the tsvector labels A, B, C, and D.
  #    The keys are label names, and the values the weights, in the range 0 to 1; if a label is not
  #    present, its value is set to 0. If this option is not present, no weights are passed to the
  #    rank functions, and the Postgres defaults will be used.
  #   @option opts [Integer] :_n A bit mask containing the normalization factors to apply to the rank
  #    values. See the Postgres documentation (for example,
  #    {https://www.postgresql.org/docs/9.6/static/textsearch-controls.html here}) for details.
  #    The default value is 16, which divides the rank by (1 + the logarithm of the number of unique
  #    words in the document); this gives an edge to shorter documents that contain the search terms.
  # 
  #   @return [String] Returns a string containing the call to the ranking function.

  # @!method add_rank_order(q, tsv, qs, opts = {})
  #   @!scope class
  #   Modify an ActiveRecord::Relation object to include a full text ranking order clause.
  #   This method makes an `order` method call containing the text rank condition.
  #
  #   Note that, unfortunately, the method currently does not place the score in the select list,
  #   so that it is not possible to return the score in the results.
  #
  #   @param q [ActiveRecord::Relation] The relation object to modify; if `nil`, uses **self**.
  #   @param tsv [String] The name of the column that contains the tsvector to use.
  #    See {.pg_rank}.
  #   @param qs [String] The query string to use.
  #    See {.pg_rank}.
  #   @param opts [Hash] Options for the ranking function.
  #    See {.pg_rank}.
  # 
  #   @return [ActiveRecord::Relation] Returns a relation object that has been modified to include a
  #    full text rank ORDER BY clause.

  class_methods do
    def pg_headline_select_item(doc_name, query, attr_name = nil, config_name = nil, opts = nil)
      a_name = ((attr_name.is_a?(String) && (attr_name.length > 0)) || attr_name.is_a?(Symbol)) ? attr_name : 'headline'
      c_name = ((config_name.is_a?(String) && (config_name.length > 0)) || config_name.is_a?(Symbol)) ? "#{config_name}, " : ''
      qs = pg_query_string(query)
      
      opts_string = if opts.is_a?(Hash)
                      ", '" + (opts.map { |e| "#{e[0]} = #{e[1]}" }).join(', ') + "'"
                    else
                      ''
                    end

      "ts_headline(#{c_name}#{doc_name}, to_tsquery('#{qs}')#{opts_string}) AS #{a_name}"
    end

    def strip_select_list(strip = [ 'headline' ])
      strip = [ strip ] unless strip.is_a?(Array)
      self.attribute_names - strip
    end

    def tokenize_query_string(qs)
      tokens = [ ]
      cur = ''
      state = :scan
      
      qs.split('').each_with_index do |c, idx|
        case c
        when '"'
          case state
          when :scan
            state = :quote
            cur = ''
          when :quote
            tokens << [ :quoted, cur.split(/\s+/).join(' ').strip ]
            state = :scan
            cur = ''
          else
            raise MalformedQuery.new(qs, idx)
          end
        when '|'
          case state
          when :scan
            tokens << [ :or ]
            cur = ''
          when :quote
            cur << c
          when :token
            tokens << [ :word, cur ]
            tokens << [ :or ]
            state = :scan
            cur = ''
          else
            raise MalformedQuery.new(qs, idx)
          end
        when '&'
          case state
          when :scan
            tokens << [ :and ]
            cur = ''
          when :quote
            cur << c
          when :token
            tokens << [ :word, cur ]
            tokens << [ :and ]
            state = :scan
            cur = ''
          else
            raise MalformedQuery.new(qs, idx)
          end
        when '-', '!'
          case state
          when :scan
            tokens << [ :minus ]
          when :quote
            cur << c
          when :around
            raise MalformedQuery.new(qs, idx) unless c == '-'
            cur = '1'
          when :token
            if c == '-'
              cur << c
            else
              if cur.upcase == 'OR'
                tokens << [ :or ]
                tokens << [ :minus ]
                state = :scan
              elsif cur.upcase == 'AND'
                tokens << [ :and ]
                tokens << [ :minus ]
                state = :scan
              elsif cur.upcase == 'AROUND'
                state = :around
              else
                tokens << [ :word, cur ]
                tokens << [ :minus ]
                state = :scan
              end
              cur = ''
            end
          else
            raise MalformedQuery.new(qs, idx)
          end
        when '<'
          case state
          when :scan
            state = :around
            cur = ''
          when :quote
            cur << c
          when :token
            tokens << [ :word, cur ]
            state = :around
            cur = ''
          else
            raise MalformedQuery.new(qs, idx)
          end
        when '>'
          case state
          when :quote
            cur << c
          when :around
            tokens << [ :around, cur.to_i ]
            state = :scan
            cur = ''
          else
            raise MalformedQuery.new(qs, idx)
          end
        when '('
          case state
          when :scan
            tokens << [ :open ]
          when :token
            if cur.upcase == 'OR'
              tokens << [ :or ]
              tokens << [ :open ]
              state = :scan
            elsif cur.upcase == 'AND'
              tokens << [ :and ]
              tokens << [ :open ]
              state = :scan
            elsif cur.upcase == 'AROUND'
              state = :around
            else
              tokens << [ :word, cur ]
            end
            cur = ''
          end
        when ')'
          case state
          when :scan
            tokens << [ :close ]
          when :token
            tokens << [ :word, cur ]
            tokens << [ :close ]
          when :around
            tokens << [ :around, cur.to_i ]
          end
          state = :scan
          cur = ''
        when ' '
          case state
          when :quote
            cur << c
          when :token
            if cur.upcase == 'OR'
              tokens << [ :or ]
            elsif cur.upcase == 'AND'
              tokens << [ :and ]
            else
              tokens << [ :word, cur ]
            end
            state = :scan
            cur = ''
          when :around
            raise MalformedQuery.new(qs, idx)
          end
        else
          case state
          when :scan
            state = :token
            cur = c
          when :token
            cur << c
          when :quote
            cur << c
          when :around
            raise MalformedQuery.new(qs, idx) unless c =~ /[0-9]/
            cur = c
          end
        end
      end

      # we need to adjust based on the final state

      case state
      when :token
        if cur.upcase == 'OR'
          tokens << [ :or ]
        elsif cur.upcase == 'AND'
          tokens << [ :and ]
        else
          tokens << [ :word, cur ]
        end
      when :quote
        # let's be lenient

        tokens << [ :quoted, cur.split(/\s+/).join(' ').strip ]
      end

      tokens
    end

    def pg_query_text(tokens)
      qs = ''
      last = :start

      tokens.each do |tok|
        case tok[0]
        when :word
          qs << ' ' unless (last == :open) || (last == :minus)
          qs << '& ' if last == :word
          qs << tok[1]
        when :quoted
          qs << ' ' unless (last == :open) || (last == :minus)
          qs << '& ' if (last == :word) || (last == :quoted)
          qs << '('
          qs << (tok[1].split(' ').map { |t| "\"#{t}\"" }).join(' <-> ')
          qs << ')'
        when :or
          qs << ' |' unless (last == :or) || (last == :and)
        when :and
          qs << ' &' unless (last == :or) || (last == :and)
        when :minus
          qs << ' &' unless (last == :or) || (last == :and) || (last == :start)
          qs << ' !'
        when :around
          qs << " <#{tok[1]}>"
        when :open
          if (last == :word) || (last == :close)
            qs << ' & '
          elsif (last == :and) || (last == :or)
            qs << ' '
          end
          qs << '('
        when :close
          qs << ')'
        end

        last = tok[0]
      end

      PG_QUERY_STRING_PREFIX + qs.strip
    end

    def pg_query_string(qs)
      qs = pg_query_text(tokenize_query_string(qs)) unless qs.start_with?(PG_QUERY_STRING_PREFIX)
      qs[PG_QUERY_STRING_PREFIX.length, qs.length]
    end

    def pg_parse_order_option(opts, pgqs = nil)
      ord = case opts[:order]
            when String
              opts[:order].split(/,\s*/)
            when Array
              opts[:order]
            when FalseClass
              nil
            else
              [ 'updated_at DESC' ]
            end
      return [ nil, nil ] if ord.nil? or (ord.count < 1)

      rank = nil

      olist = ord.map do |e|
        e = e.strip
        if e =~ /^rank/i
          if pgqs && (pgqs.length > 0)
            a = e.split(/\s+/)
            rank_opts = case opts[:rank]
                        when String
                          o = JSON::parse(opts[:rank])
                          case o
                          when Hash
                            o
                          else
                            {}
                          end
                        when Hash
                          opts[:rank]
                        when ActionController::Parameters
                          opts[:rank].to_h
                        else
                          {}
                        end

            # The rank order clause triggers a warning in Rails 5:
            # - Dangerous query method (method whose arguments are used as raw SQL) called with
            #   non-attribute argument(s)
            # - Non-attribute arguments will be disallowed in Rails 6.0
            # Since we have put together the rank clause ourselves and we know it's safe, we wrap in
            # an Arel.sql statement to let ActiveRecord know that all is good
            
            rank = pg_rank(rank_opts[:tsv], PG_QUERY_STRING_PREFIX + pgqs, rank_opts)
            if a.count > 1
              Arel.sql([ rank, a[1] ].join(' '))
            else
              Arel.sql([ rank, 'DESC' ].join(' '))
            end
          else
            'updated_at DESC'
          end
        else
          e
        end
      end

      [ olist, rank ]
    end

    def pg_where(doc_name, tsv, qs, cfg = nil)
      pgqs = pg_query_string(qs)
      scfg = if cfg.is_a?(String) || cfg.is_a?(Symbol)
               s = cfg.to_s.downcase
               (s.start_with?('pg_catalog.')) ? "'#{s}', " : "'pg_catalog.#{s}', "
             else
               ''
             end
      tsv = "to_tsvector(#{doc_name})" unless (tsv.is_a?(String) && (tsv.length > 0)) || tsv.is_a?(Symbol)

      "(#{tsv} @@ to_tsquery(#{scfg}'#{pgqs}'))"
    end

    def add_full_text_query(q, doc_name, tsv, qs, opts = {})
      pgqs = pg_query_string(qs)
      q = self if (q.nil?)

      if opts.has_key?(:with_headline) && opts[:with_headline]
        hl = ((opts[:with_headline].is_a?(String) && (opts[:with_headline].length > 0)) || opts[:with_headline].is_a?(Symbol)) ? opts[:with_headline] : 'headline'
        q = q.select(strip_select_list(hl).append(pg_headline_select_item(doc_name, pgqs, hl)))
      end

      q = q.where(pg_where(doc_name, tsv, qs, opts[:with_configuration]))

      q
    end

    def pg_rank(tsv, qs, opts = {})
      pgqs = pg_query_string(qs)
      rs = case opts[:_f]
           when 'ts_rank', :ts_rank, 'ts_rank_cd', :ts_rank_cd
             "#{opts[:_f]}("
           else
             'ts_rank('
           end

      if opts[:_w].is_a?(Hash)
        w = [:D, :C, :B, :A].map { |k| (opts[:_w][k].nil?) ? 0 : opts[:_w][k].to_f }
        rs += "array#{w}, "
      end

      norm = (opts[:_n].is_a?(Integer)) ? opts[:_n] : 16

      rs += "#{tsv}, to_tsquery('#{pgqs}'), #{norm})"

      rs
    end

    def add_rank_order(q, tsv, qs, opts = {})
      r = pg_rank(tsv, qs, opts)
      q = self if (q.nil?)
      q = q.order("#{r} DESC")

      q
    end
  end

  # Executed when the module is included in a class.

  included do
    const_set(:PG_QUERY_STRING_PREFIX, PG_QUERY_STRING_PREFIX) unless const_defined?(:PG_QUERY_STRING_PREFIX)
  end
end
