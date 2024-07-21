# A concern to manage request parameters.
# Include it in a controller or (more typically) service object code, like this:
#
# ```
# class ApplicationController < ActionController::Base
#   include Fl::Core::Concerns::Service::Params
# end
# ```
#
# The base service object {Fl::Core::Service::Base} includes this concern, so that there is no need to do so
# in its subclasses.

module Fl::Core::Concerns::Service::Params
  extend ActiveSupport::Concern

  protected

  # Create a copy of a hash where all keys have been converted to symbols.
  # The operation is applied recursively to all values that are also keys.
  # Additionally, the **:id** key (if present) and any key that ends with `_id` are copied to a key with the
  # same name, prepended by an underscore; for example, **:id** is copied to **:_id** and **:user_id** to
  # **:_user_id**.
  #
  # This method is typically used to normalize the `params` value.
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
  # This method returns the value of *p*, converted as necessary.
  # For example, some clients (Axios for one) convert complex parameter values into JSON representations,
  # rather than building the traditional nested set of parameter names. This method assumes that a string
  # value for *key* is a JSON representation and processes it accordingly.
  #
  # @param p [Hash,ActionController::Params,String] The parameter value.
  #
  # @return [ActionController::Parameters] Returns the parameter value. Controllers
  #  are responsible for allowing only permitted ones.

  def normalize_param_value(p)
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
  # This is a wrapper around {#normalize_param_value}, using the parameter **:_q**.
  #
  # @param p [Hash,ActionController::Params,String] The parameter value. A `nil` value uses the **:_q** key in
  #  `params`.
  #
  # @return [ActionController::Parameters] Returns the query parameters. Controller implementations
  #  of {Fl::Core::Service::Base#query_params} are responsible for allowing only permitted ones.

  def normalize_query_params(p = nil)
    p = params.fetch(:_q, {}) if p.nil?
    normalize_param_value(p)
  end

  # Get the pagination parameters.
  # Looks up the **:_pg** key in +params+ and returns the permitted values.
  # Some clients (Axios for one) convert complex parameter values into JSON representations, rather
  # than building the traditional nested set of parameter names. This method assumes that a string
  # value for **:_pg** is a JSON representation and processes it accordingly.
  #
  # @param pg [Hash,ActionController::Params,String] The parameter value. A `nil` value uses the **:_q** key in
  #  `params`.
  #
  # @return [ActionController::Parameters] Returns the permitted pagination parameters, which are:
  # - **:_s** The page size.
  # - **:_p** The starting page (the first page is 1).
  # - **:_c** The count of items returned by the query. This is typically not used when generating
  #   query parameters, but rather is returned by the query.

  def pagination_params(pg = nil)
    pg = params.fetch(:_pg, {}) if pg.nil?
    normalize_param_value(pg).permit(:_s, :_p, :_c)
  end

  # @!method strong_params(sp)
  #   @scope class
  #   Convert parameters to `ActionController::Parameters`.
  #   This method expects *sp* to contain a hash, or a JSON representation of a hash, of parameters,
  #   and converts it to `ActionController::Parameters`.
  #
  #   1. If *sp* is a string value, it assumes that the client has generated
  #      a JSON representation of the parameters, and parses it into a hash.
  #   2. If the value is already a `ActionController::Parameters`, it returns it as is;
  #      otherwise, it constaructs a new `ActionController::Parameters` instance from the hash value.
  #
  #   @param sp [Hash,ActionController::Parameters,String] The parameters to convert.
  #    If a string value, it is assumed to contain a JSON representation.
  #
  #   @return [ActionController::Parameters] Returns the converted parameters.

  class_methods do
    def strong_params(sp)
      sp = JSON.parse(sp) if sp.is_a?(String)
      (sp.is_a?(ActionController::Parameters)) ? sp : ActionController::Parameters.new(sp)
    end
  end
  
  # Include callback.
  # This method is currently empty.

  included do
  end
end
