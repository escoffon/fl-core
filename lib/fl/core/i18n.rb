# Extend the functionality of Rails' I18n module to add support for the following:
#
# * When looking up a translation for a locale, try successive subsets of the locale components to implement
#   "translation string inheritance." For example, for +en-us+, first look up in +en-us+,
#   and then in +en+.
# * Support lookups over an array of locales, rather than a single one. The application can set an array
#   of locales, and the extension methods look up locales in the array order and return the first
#   translation hit. For example, if the locale array is <code>[ 'en-us', 'it', 'es' ]</code>, the
#   extension methods look up translations for +en-us+, +en+, +it+, and +es+ until a match is found.

module I18n
  class << self
    # Gets the locale array.
    # This value is scoped to thread like +locale+.
    # It defaults to the array containing the +default_locale+.
    # 
    # @return [Array<Symbol>] Returns an array of locales.

    def locale_array
      config.locale_array
    end

    # Sets the current locale array pseudo-globally, i.e. in the +Thread.current+ hash.
    #
    # @param locale_array [Array<Symbol, String>] An array of locale names; strings are converted to symbols.
    #
    # @return [Array<Symbol>] Returns the array of locales that was set.

    def locale_array=(locale_array)
      config.locale_array = locale_array
    end

    # Extend the functionality of I18n's translate method.
    # This method has the same call and return signature as +translate+, but it looks up locales from
    # {.locale_array} as described in the documentation header.
    #
    # Aliased to +tx+ for convenience.
    #
    # @overload translate_x(key, options)
    #  @param key [String] The lookup key.
    #  @param options [Hash] Options; these parameters take the same form as those for +translate+, with
    #   the following modifications:
    #   - If +:locale+ is present in the options, check its type.
    #     If a string, just call :translate:; if an array, process the locales in the array instead
    #     of from {.locale_array}.
    #
    # @return Returns the same type and value as +translate+.

    def translate_x(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      key     = args.shift
      handling = options.delete(:throw) && :throw || options.delete(:raise) && :raise # TODO deprecate :raise

      if options.has_key?(:locale) && !options[:locale].is_a?(Array)
        translate(key, options)
      else
        begin
          raise I18n::ArgumentError if key.is_a?(String) && key.empty?

          if key.is_a?(Array)
            if handling
              options[handling] = true
            end
            key.map { |k| translate_x(k, options) }
          else
            backend = config.backend
            locales = if options.has_key?(:locale) && options[:locale].is_a?(Array)
                        options.delete(:locale)
                      else
                        config.locale_array
                      end

            # we need to drop :default from the options, or we won't find a translation if a later
            # locale has one and the first does not

            default = options.delete(:default)
            options[:raise] = true

            seen = {}

            locales.each do |lloc|
              aloc = lloc.to_s.split('-')
              while aloc.length > 0
                l = aloc.join('-')
                unless seen.has_key?(l)
                  seen[l] = true
                  begin
                    return backend.translate(l, key, options)
                  rescue I18n::ReservedInterpolationKey => ex
                    raise
                  rescue
                  end
                end
                aloc.pop
              end
            end

            # if we made it here, there is no translation

            if default
              default
            else
              raise I18n::MissingTranslationData.new(locales, key, options)
            end
          end
        rescue I18n::ArgumentError => exception
          handle_exception(handling, exception, locale, key, options)
        end
      end
    end
    alias :tx :translate_x

    # This version of {.translate_x} sets the +:raise+ option.
    #
    # Aliased to +tx!+ for convenience.
    #
    # @param key [String] The lookup key.
    # @param options [Hash] Options; see {.translate_x}.
    #
    # @return Returns the same type and value as +translate+.
    #
    # @raise if the translation lookup fails.

    def translate_x!(key, options={})
      translate_x(key, options.merge(:raise => true))
    end
    alias :tx! :translate_x!

    # Extend the functionality of I18n's localize method.
    # This method has the same call and return signature as +localize+.
    #
    # Aliased to +lx+ for convenience.
    #
    # @param object The object to localize.
    # @param options [Hash] Options; these parameters take the same form as those for +localize+, with the
    #  following modifications:
    #  - If +:locale+ is present in the options, check its type.
    #    If a string, just call +localize+; if an array, process the locales in the array.
    #
    # @return Returns the same type and value as +localize+.

    def localize_x(object, options = {})
      if options.has_key?(:locale) && !options[:locale].is_a?(Array)
        localize(object, options)
      else
        begin
          handling = options.delete(:throw) && :throw || options.delete(:raise) && :raise # TODO deprecate :raise
          if object.is_a?(Array)
            if handling
              options[handling] = true
            end
            object.map { |k| localize_x(k, options) }
          else
            backend = config.backend
            locales = if options.has_key?(:locale) && options[:locale].is_a?(Array)
                        options.delete(:locale)
                      else
                        config.locale_array
                      end
            format = options.delete(:format) || :default

            # we need to drop :default from the options, or we won't find a translation if a later
            # locale has one and the first does not

            default = options.delete(:default)
            options[:raise] = true

            seen = {}

            locales.each do |lloc|
              aloc = lloc.to_s.split('-')
              while aloc.length > 0
                l = aloc.join('-')
                unless seen.has_key?(l)
                  seen[l] = true
                  begin
                    return backend.localize(l, object, format, options)
                  rescue
                  end
                end
                aloc.pop
              end
            end

            # if we made it here, there is no translation

            if default
              default
            else
              raise I18n::MissingTranslationData.new(locales, object, options)
            end
          end
        rescue I18n::ArgumentError => exception
          handle_exception(handling, exception, locale, object, options)
        end
      end
    end
    alias :lx :localize_x

    # Parse the Accept-Language HTTP header.
    # This method splits the Accept-Language HTTP header (if present) into an array containing
    # the locales listed in the header, sorted by their +q+ value.
    #
    # @param request The current request object.
    #
    # @return Returns an array of strings containing the locales listed in Accept-Language,
    #  and sorted by descending +q+ value. The locales are canonicalized: names are in lowercase, and 
    #  underscores have been converted to dashes. If Accept-Language is not present, it returns an array
    #  containing the default locale.

    def parse_accept_language(request)
      if request.env.has_key?('HTTP_ACCEPT_LANGUAGE')
        raw_locales = request.env['HTTP_ACCEPT_LANGUAGE'].split(',').map do |l|
          a = l.split(';')
          if a.length == 1
            [ a[0].strip, 1.0 ]
          else
            if a[1] =~ /^\s*q=([01](\.[0-9])?)/i
              d = Regexp.last_match
              [ a[0].strip, d[1].to_f ]
            else
              [ a[0].strip, 1.0 ]
            end
          end
        end

        raw_locales.sort! { |e1, e2| e2[1] <=> e1[1] }
        raw_locales.map { |e| e[0].gsub('_', '-').downcase }
      else
        [ config.locale ]
      end
    end
  end

  # Adds the +locale_array+ pseudo-global property to the I18n Config object.

  class Config
    # Gets the locale array.
    # This value is scoped to thread like +locale+.
    # It defaults to the array containing the +default_locale+.
    # 
    # @return [Array<Symbol>] Returns an array of locales.

    def locale_array
      begin
        @locale_array ||= [ default_locale.to_sym ]
      rescue
        nil
      end
    end

    # Sets the current locale array pseudo-globally, i.e. in the +Thread.current+ hash.
    #
    # @param locale_array [Array<Symbol, String>] An array of locale names; strings are converted to symbols.
    #
    # @return [Array<Symbol>] Returns the array of locales that was set.

    def locale_array=(locale_array)
      begin
        @locale_array = locale_array.map { |l| l.to_sym }
      rescue
        nil
      end
    end
  end
end

# Extensions to the ActionView module.

module ActionView
  # Extensions to the ActionView helpers module.

  module Helpers
    # Extends ActionView::Helpers::TranslationHelper with the I18n extensions.
    # The code template originated from actionview-4.2.6/lib/action_view/helpers/translation_helper.rb

    module TranslationHelper
      # Extended version of +translate+ that uses the locale array instead of a single locale.
      # The arguments and return value asre equivalent to those in +translate+
      #
      # Aliased to +tx+ for convenience.
      #
      # @param key [String] The lookup key.
      # @param options [Hash] Options; see {I18n.translate_x}.
      #
      # @return Returns the same type and value as {I18n.translate_x}.

      def translate_x(key, options = {})
        options = options.dup
        has_default = options.has_key?(:default)
        remaining_defaults = Array(options.delete(:default)).compact

        if has_default && !remaining_defaults.first.kind_of?(Symbol)
          options[:default] = remaining_defaults
        end

        # If the user has explicitly decided to NOT raise errors, pass that option to I18n.
        # Otherwise, tell I18n to raise an exception, which we rescue further in this method.
        # Note: `raise_error` refers to us re-raising the error in this method. I18n is forced to raise by default.
        if options[:raise] == false || (options.key?(:rescue_format) && options[:rescue_format].nil?)
          raise_error = false
          i18n_raise = false
        else
          raise_error = options[:raise] || options[:rescue_format] || ActionView::Base.raise_on_missing_translations
          i18n_raise = true
        end

        if html_safe_translation_key?(key)
          html_safe_options = options.dup
          options.except(*I18n::RESERVED_KEYS).each do |name, value|
            unless name == :count && value.is_a?(Numeric)
              html_safe_options[name] = ERB::Util.html_escape(value.to_s)
            end
          end
          translation = I18n.translate_x(scope_key_by_partial(key), html_safe_options.merge(raise: i18n_raise))

          translation.respond_to?(:html_safe) ? translation.html_safe : translation
        else
          I18n.translate_x(scope_key_by_partial(key), options.merge(raise: i18n_raise))
        end
      rescue I18n::MissingTranslationData => e
        if remaining_defaults.present?
          translate_x remaining_defaults.shift, options.merge(default: remaining_defaults)
        else
          raise e if raise_error

          keys = I18n.normalize_keys(e.locale, e.key, e.options[:scope])
          content_tag('span', keys.last.to_s.titleize, :class => 'translation_missing', :title => "translation missing: #{keys.join('.')}")
        end
      end
      alias :tx :translate_x
    end
  end
end

# Extensions of the AbstractController module.

module AbstractController
  # Extends AbstractController::Translation with the I18n extensions.
  # The code template originated from actionpack-4.2.6/lib/abstract_controller/translation.rb.

  module Translation
    # Extended version of +translate+ that uses the locale array instead of a single locale.
    # The arguments and return value are equivalent to those in +translate+
    #
    # Aliased to +tx+ for convenience.
    #
    # @overload translate_x(key, options)
    #  @param key [String] The lookup key.
    #  @param options [Hash] Options; see {I18n.translate_x}.
    #
    # @return Returns the same type and value as {I18n.translate_x}.

    def translate_x(*args)
      key = args.first
      if key.is_a?(String) && (key[0] == '.')
        key = "#{ controller_path.tr('/', '.') }.#{ action_name }#{ key }"
        args[0] = key
      end

      I18n.translate_x(*args)
    end
    alias :tx :translate_x
  end
end

# Plugin extensions for the ApplicationController.
# Include this module in ApplicationController to augment the controller API:
#
# ```
#  class ApplicationController < ActionController::Base
#    include I18nExtension
#    before_filter :set_locale_from_http_header
#  end
# ```
# The include defines the {I18nExtension#set_locale_from_http_header}, which you can then use as a
# +before_filter+ to set up the locale array from the Accept-Language HTTP header.
# As a side effect, the I18n module is augmented with the I18n#translate_x method (and support APIs),
# and the +tx+ method is added to the helpers, equivalently to the standard I18n +t+ method.

module I18nExtension
  # Sets the I18n locale array from the Accept-Language HTTP header.
  # This method parses the Accept-Language header and sets the locale array appropriately.
  # Typically used as a +before_filter+:
  #
  # ```
  #  class ApplicationController < ActionController::Base
  #    include I18nExtension
  #    before_filter :set_locale_from_http_header
  #  end
  # ```
  #
  # Note if the +en+ locale is not in the HTTP header, it is appended at the end of the array to provide
  # a failsafe backstop.

  def set_locale_from_http_header()
    loc = I18n.parse_accept_language(request)
    loc << 'en' unless loc.include?('en')
    I18n.locale_array = loc
  end
end
