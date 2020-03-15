# A concern to manage request parameters.
# Include it in a controller code, like this:
#
# ```
# class ApplicationController < ActionController::Base
#   include Fl::Core::Concerns::Controller::Params
# end
# ```

module Fl::Core::Concerns::Controller::Params
  extend ActiveSupport::Concern

  protected

  # Create a copy of a hash where all keys have been converted to symbols.
  # The operation is applied recursively to all values that are also keys.
  # Additionally, the **:id** key (if present) and any key that ends with `_id` are copied to a key with the
  # same name, prepended by an underscore; for example, **:id** is copied to **:_id** and **:user_id** to
  # **:_user_id**.
  #
  # This method is typically used to normalize the +params+ value.
  #
  # @param h [Hash] The hash to normalize.
  #
  # @return [Hash] Returns a new hash where all keys have been converted to symbols. This operation
  #  is applied recursively to hash values.

  def normalize_params(h = nil)
    h = params unless h.is_a?(Hash)
    hn = {}
    re = /.+_id$/i
    
    h.each do |hk, hv|
      case hv
      when ActionController::Parameters
        hv = normalize_params(hv.to_h)
      when Hash
        hv = normalize_params(hv)
      end

      hn[hk.to_sym] = hv
      shk = hk.to_s
      hn["_#{shk}".to_sym] = (hv.is_a?(String) ? hv.dup : hv) if (shk == 'id') || (shk =~ re)
    end

    hn
  end

  # Normalize the value of a parameter.
  # This method returns the value of the *key* in `params`, converted as necessary.
  # For example, some clients (Axios for one) convert complex parameter values into JSON representations,
  # rather than building the traditional nested set of parameter names. This method assumes that a string
  # value for *key* is a JSON representation and processes it accordingly.
  #
  # @param key [Symbol,String] The key for the parameter; a string value is converted to a symbol.
  #
  # @return [ActionController::Parameters] Returns the parameter value. Controllers
  #  are responsible for allowing only permitted ones.

  def normalize_param_value(key)
    p = params.fetch(key.to_sym, {})
    case p
    when Hash
      ActionController::Parameters.new(p)
    when ActionController::Parameters
      p
    when String
      begin
        ActionController::Parameters.new(normalize_params(JSON.parse(p)))
      rescue
        ActionController::Parameters.new({ })
      end
    else
      ActionController::Parameters.new({ })
    end
  end

  # Normalize the query parameters.
  # This is a wrapper around {#normalize_param_value}, using the key **:_q**.
  #
  # @return [ActionController::Parameters] Returns the query parameters. Controller implementations
  #  of {#query_parameters} are responsible for allowing only permitted ones.

  def normalize_query_params()
    normalize_param_value(:_q)
  end

  # Default accessor for the query parameters.
  # Provided in case that controllers don't define an implementation (which they should).
  #
  # @return [ActionController::Parameters] Returns the default parameters, which are currently an
  #  empty set.

  def query_params()
    ActionController::Parameters.new({ })
  end

  # Get the pagination parameters.
  # Looks up the **:_pg** key in +params+ and returns the permitted values.
  # Some clients (Axios for one) convert complex parameter values into JSON representations, rather
  # than building the traditional nested set of parameter names. This method assumes that a string
  # value for **:_pg** is a JSON representation and processes it accordingly.
  #
  # @return [ActionController::Parameters] Returns the permitted pagination parameters, which are:
  # - **:_s** The page size.
  # - **:_p** The starting page (the first page is 1).
  # - **:_c** The count of items returned by the query. This is typically not used when generating
  #   query parameters, but rather is returned by the query.

  def pagination_params()
    normalize_param_value(:_pg).permit(:_s, :_p, :_c)
  end

  # Class methods.

  class_methods do
  end
  
  # Include callback.
  # This method is currently empty.

  included do
  end
end
