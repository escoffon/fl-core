require 'fl/core/query/filter_generator'

module Fl::Core::Query::FilterGenerator
  # Implements the **:custom** filter type.
  # This class lets you define your own clause generator. It executes the block stored in the **:generator**
  # configuration option, and uses the value returned by the block. This block is called with the following arguments:
  #
  # 1. *g* is the filter generator (the instance of {Fl::Core::Query::Filter} running the
  #    {Fl::Core::Query::Filter#generate} method).
  # 2. *n* is the filter name.
  # 3. *d* is the filter descriptor.
  # 4. *v* is the filter value.
  #
  # The contents of the filter value (*v*) are arbitrary. If the block returns `nil`, no clause is generated.
  
  class Custom < Base
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
      return filter.generate_custom_clause(name, desc, value)
    end
  end
end
