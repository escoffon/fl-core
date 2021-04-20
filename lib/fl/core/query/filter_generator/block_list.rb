require 'fl/core/query/filter_generator'

module Fl::Core::Query::FilterGenerator
  # Implements the **:block_list** filter type.
  # This class generates a WHERE clause that filters based on the `IN` operator; it expects a value
  # containing the two keys **:only** and **:except**, which list objects that should be included in, or excluded
  # from, the result set. Specifically:
  #
  # 1. It converts the values of **:only** and **:except** to arrays, using the Proc (block) that was defined
  #    in the **:convert** property of the descriptor.
  # 2. If **:except** is not present or is an empty array, it generates a WHERE clause where the column name in the
  #    **:field** configuration option is `IN` the **:only** list.
  # 3. If both **:only** and **:except** are present, it removes the members of **:except** from **:only**, and then
  #    proceeds as for step 2.
  # 4. If only **:except** is present, it generates a WHERE clause where the column name in the
  #    **:field** configuration option is `NOT IN` the **:except** list.
  #    Note, however, that if the **:except** list is empty, then no clause is generated: if we except no values,
  #    then all records should be returned.
  #
  # So {Fl::Core::Query::FilterGenerator::References} applies to columns that contain arbitrary values that should
  # be match against a list of possible values.
  
  class BlockList < Base
    # Generate a WHERE clause.
    # See the class description, above.
    #
    # @param name [Symbol] The name of the filter. This is the value of a key in the *body* argument to
    #  {Fl::Core::Query::Filter#generate}. It is also the value of a key in the **:filter** option of the
    #  filter configuration passed to {Fl::Core::Query::Filter#initialize}.
    # @param desc [Hash] The filter descriptor; this is the value in the **:filters** option corresponding
    #  to *name*.
    # @param value [any] The filter value; this is the value of the node in the *body* argument that triggered
    #  this calls.
    #
    # @return [String, nil] Returns a string containing the WHERE clause; if no WHERE clause should be emitted
    #  by {#filter}, returns `nil`.
    
    def generate_simple_clause(name, desc, value)
      ph = Fl::Core::Query::FilterHelper.normalize_filter_lists(filter, value) do |f, l, e|
        desc[:convert].call(f, l, e)
      end
      if desc[:generator]
        return desc[:generator].call(filter, name, desc, ph)
      else
        return filter.generate_partitioned_clause(name, desc, ph)
      end
    end
      
    # Normalize a filter value.
    # Passes the **:only** and **:except** properties of *value* to the Proc (block) that was defined
    # in the **:convert** property of *desc* and installs the Proc's return value as the new value.
    #
    # @param name [Symbol] The name of the filter. This is the value of a key in the *body* argument to
    #  {Fl::Core::Query::Filter#generate}. It is also the value of a key in the **:filter** option of the
    #  filter configuration passed to {Fl::Core::Query::Filter#initialize}.
    # @param desc [Hash] The filter descriptor; this is the value in the **:filters** option corresponding
    #  to *name*.
    # @param value [any] The filter value; this is the value of the node in the *body* argument that triggered
    #  this calls.
    #
    # @return [any] Returns the normalized filter value.
      
    def normalize_value(name, desc, value)
      nv = (value.is_a?(Hash)) ? value : { }

      if desc[:convert]
        if nv.has_key?(:only)
          nv[:only] = desc[:convert].call(self, nv[:only], :only)
        end

        if nv.has_key?(:except)
          nv[:except] = desc[:convert].call(self, nv[:except], :except)
        end
      end

      return nv
    end
  end
end
