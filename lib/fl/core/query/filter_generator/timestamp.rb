require 'fl/core/query/filter_generator'

module Fl::Core::Query::FilterGenerator
  # Implements the **:timestamp** filter type.
  # This class generates a WHERE clause that selects column values that compare with the filter value provided.
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
  
  class Timestamp < Base
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
      if desc[:generator]
        return desc[:generator].call(filter, name, desc, value)
      else
        return filter.generate_timestamp_clause(name, desc, value)
      end
    end
  end
end
