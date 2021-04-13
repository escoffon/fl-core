module Fl::Core::Query
  # Namespace for filter generators.

  module FilterGenerator
    # The exception raised by the filter generator.

    class Exception < RuntimeError
    end
      
    # Base class for filter generators.
    # Instances of this class do the actual work of generating WHERE clauses.
    #
    # The {Fl::Core::Query::Filter#generate} method walks the contents of its *body* filter, assembling a final
    # compound WHERE clause. Leaf nodes in *body* trigger a call to the {#generate_simple_clause} method of
    # the filter corresponding to the node. The return value is added to the compound clause, and side effects
    # in the method contribute to the overall state of the filter. (Typically, these are calls to
    # {Fl::Core::Query::Filter#allocate_parameter} to register any bind parameters used by the clause.)
    #
    # This base class defines the API for the clause generator; subclasses have to be defined in order to
    # implement specific filter strategies. The {Fl::Core::Query::Filter} class registers some standard
    # generators; more can be added in the **:generators** option to the filter configuration.
    
    class Base
      # Initializer.
      #
      # @param filter [Fl::Core::Query::Filter] The filter object that provides the context in which a clause
      #  is generated.

      def initialize(filter)
        @filter = filter
      end

      # The filter that provides the conext for the generator.
      #
      # @return [Fl::Core::Query::Filter] Returns the filter that was passed to the initializer.

      attr_reader :filter
      
      # Generate a WHERE clause.
      # This method builds the WHERE clause in the context of its {#filter}. It allocates bind parameters as
      # needed using {Fl::Core::Query::Filter#allocate_parameter}, and returns the contents of the clause.
      #
      # The base implementation returns `nil`; subclasses are expected to override this method and implement
      # their specific generation process.
      #
      # Note that it is likely that implementations of this method will have side effects, in particular calls
      # to {Fl::Core::Query::Filter#allocate_parameter} to register bind parameters based on the contents
      # of *value*.
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
        return nil
      end
    end
  end
end
