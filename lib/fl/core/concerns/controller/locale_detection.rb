# Locale detection in controllers.
# Include it in controller code, like this:
#
# ```
# class ApplicationController < ActionController::Base
#   include Fl::Core::Concerns::Controller::LocaleDetection
# end
# ```
#
# This concern registers a `around_action` wrapper that sets up the locale list for the action.

module Fl::Core::Concerns::Controller::LocaleDetection
  extend ActiveSupport::Concern

  # Extracts the locales list from the request.
  # Generates the list of locales to look up from the following values (the first hit returns):
  #
  # 1. If the request URL contains the `_loc` parameter.
  # 2. If the `Accept-Language` header is present.
  # 3. From the default locale list.

  def extract_locales()
    if params.has_key?(:_loc)
      return (params[:_loc].is_a?(Array)) ? params[:_loc] : params[:_loc].split(',').map { |l| l.to_s.trim }
    elsif request.env.has_key?('HTTP_ACCEPT_LANGUAGE')
      locales = I18n.parse_accept_language(request)
      return locales if locales.count > 0
    end

    return I18n.locale_array
  end

  # Wraps a controller action to set the locales list.
  
  def switch_locale_array(&action)
    I18n.with_locale_array(extract_locales, &action)
  end

  # Class methods.

  class_methods do
  end
  
  # Include callback.
  # This block registers the `around_action` for {#switch_locale_array}.

  included do
    around_action :switch_locale_array
  end
end
