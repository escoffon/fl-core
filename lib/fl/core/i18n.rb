# Extend the functionality of Rails' I18n module to add support for the following functionality:
#
# * Look up from a list of locales, rather than from a single one. The application can set an array
#   of locales, and the extension methods look up locales in the array order and return the first
#   translation hit. For example, if the locale array is <code>[ 'en-us', 'en', 'it', 'es' ]</code>, the
#   extension methods look up translations for `en-us`, `en`, `it`, and `es` until a match is found.
# * Adds the {.with_locale_array} to execute a block of code with custom locales.

module I18n
  # Fl extensions to I18n.
  # This module packages the extension methods; it is added to I18n via a call to `extend Fl`.

  module Fl
    # @!scope class
    # Gets the locale array.
    # This value is scoped to thread like `locale`.
    # It defaults to the array containing the `default_locale`.
    # 
    # @return [Array<Symbol>] Returns an array of locales.
    #
    # @!scope class

    def locale_array
      config.locale_array
    end

    # @!scope class
    # Sets the current locale array pseudo-globally, i.e. in the `Thread.current` hash.
    #
    # @param locale_array [Array<Symbol, String>] An array of locale names; strings are converted to symbols.
    #
    # @return [Array<Symbol>] Returns the array of locales that was set.

    def locale_array=(locale_array)
      config.locale_array = locale_array
    end

    # @!scope class
    # Executes a block with a given locale array set.
    # This method sets the locale array, executes the block, and resets it to the original value.
    #
    # @param locale_array [Array<Symbol, String>,nil] An array of locale names; strings are converted to symbols.
    #  A `nil` value clears the locale array.
    #
    # @yield No parameters are passed to the block.
    #
    # @yieldreturn No value is expected from the block.
    
    def with_locale_array(tmp_locale_array = nil)
      if tmp_locale_array == nil
        yield
      else
        current_locale_array = self.locale_array
        current_locale = self.locale
        self.locale_array = tmp_locale_array
        self.locale = tmp_locale_array.first
        begin
          yield
        ensure
          self.locale_array = current_locale_array
          self.locale = current_locale
        end
      end
    end
    
    # @!scope class
    # Extend the functionality of I18n's `translate` method.
    # This method has the same call and return signature as `translate`, but it looks up locales from
    # {.locale_array} as described in the documentation header.
    #
    # Aliased to `tx` for convenience.
    #
    # @overload translate_x(key, options)
    #  @param key [String] The lookup key.
    #  @param options [Hash] Options; these parameters take the same form as those for `translate`, with
    #   the following modifications:
    #
    #   - A scalar value for **:locale** in *options*, if present, is converted to a one-element array.
    #   - If **:default** is a string or a symbol, it is used for all keys in *key*.
    #     If it is an array of arrays, each element is used as the defaults for the corresponding *key* element.
    #     If it is an array of strings and symbols, it is used as the default for all elements of *key*.
    #     String defaults are applied after all locales have tried, so that symbol lookups have the precedence
    #     over string defaults: we need to do this to give all locales a chance to run the translation.
    #
    #  Note that *key* and the **default** option must be consistent with each other:
    #
    #  - If *key* is a scalar, **:default* can be a scalar of an array, but if the latter it may not contain
    #    arrays.
    #  - If *key* is an array, :default can be a scalar or an array, but if **:default** contains at least one
    #    array, then it must contain only arrays; it also must have the same number of elements as *key*.
    #
    #  So for a scalar *key*, the value of **:default** has the same semantics as for `translate`.
    #  For an array *key*, the value of **:default** has two interpretations: if it is an array of arrays, it
    #  lists the defaults for each key, individually; if it is a scalar or a mixed array, it lists a common set
    #  of defaults for all keys.
    #
    # @return Returns the same type and value as `translate`.

    def translate_x(key = nil, *, throw: false, raise: false, locale: nil, **options) # TODO deprecate :raise
      locale ||= config.locale_array
      raise Disabled.new('t') if locale == false
      locale = [ locale ] unless locale.is_a?(Array)

      raise ArgumentError.new('nil key parameter') if key.nil?
        
      nopts = options.dup
      default = nopts.delete(:default)

      # we separate string values from the others, because we want to give all locales a shot at the translation.
      # This means that string defaults have the lowest priority, even though they may have been listed first;
      # this should be OK, though, since it does not make a lot of sense to have a string value listed first
      # (because all other values will then be ignored)
      
      if key.is_a?(Array)
        if default.is_a?(Array)
          if default.any? { |e| e.is_a?(Array) }
            unless default.all? { |e| e.is_a?(Array) }
              raise ArgumentError.new(":default must contain only arrays if it contains at least one")
            end

            raise ArgumentError.new(":default must have as many elements as *key*") if key.count != default.count

            batch = [ ]
            key.each_with_index do |k, ik|
              case default[ik]
              when Array
                d2, d1 = default[ik].partition { |e| (e.is_a?(String) || e.is_a?(Hash)) }
              when String, Hash
                d1 = nil
                d2 = default[ik]
              when Symbol
                d1 = default[ik]
                d2 = nil
              end
              
              batch.push([ k, d1, d2 ])
            end
          else
            # an array value for default with no arrays means a constant default for all keys

            d2, d1 = default.partition { |e| (e.is_a?(String) || e.is_a?(Hash)) }
            batch = key.map { |k| [ k, d1, d2 ] }
          end
        else
          # a scalar value for default means a constant default for all keys

          case default
          when String, Hash
            d1 = nil
            d2 = [ default ]
          when Symbol
            d1 = [ default ]
            d2 = nil
          end
          
          batch = key.map { |k| [ k, d1, d2 ] }
        end
      else
        if default.is_a?(Array)
          if default.any? { |e| e.is_a?(Array) }
            raise ArgumentError.new(":default may not contain array values if *key* is a scalar")
          end
        end

        case default
        when Array
          d2, d1 = default.partition { |e| (e.is_a?(String) || e.is_a?(Hash)) }
        when String, Hash
          d1 = nil
          d2 = [ default ]
        when Symbol
          d1 = [ default ]
          d2 = nil
        end

        batch = [ [ key, d1, d2 ] ]
      end

      # OK, now we can get the translations for each key in the batch.
      # We iterate on keys first, so that the best individual translation per
      # key element is returned. For example, if *key* has 4 elements, and one does not have an :it translation, then
      # all elements are returned using the :en locale, whereas we want to return 3 in :it and just the one in :en

      backend = config.backend

      translations = batch.map do |k|
        ro = locale.reduce(nil) do |res, loc|
          if k[1]
            nopts[:default] = k[1]
          else
            nopts.delete(:default)
          end
          res = catch(:exception) do
            backend.translate(loc, k[0], nopts)
          end

          break res unless res.is_a?(MissingTranslation)
          res
        end

        ro
      end

      # now we need to check that all keys were translated: convert any MissingTranslation to strings or raise
      # exceptions.

      it = -1
      tl = translations.map do |t|
        it += 1
        
        if t.is_a?(MissingTranslation)
          # one last check: if there is a backstop value, replace it here.

          d2 = batch[it][2]
          if d2.is_a?(Array) && (d2.first.is_a?(String) || d2.first.is_a?(Hash))
            d2.first
          else
            # We need to create a new exception, since the one in `t` contains the error message for the
            # last backend.translate call, which contains just the last locale.

            nx = MissingTranslation.new("[#{locale.join(',')}]", t.key, nopts)
            handle_exception((throw && :throw || raise && :raise), nx, locale, key, nopts)
          end
        else
          t
        end
      end

      # one last thing: if *key* is a scalar, then we return the first element in the translations

      return (key.is_a?(Array)) ? tl : tl.first
    end
    alias :tx :translate_x
    
    # @!scope class
    # This version of {.translate_x} sets the `:raise` option.
    #
    # Aliased to `tx!` for convenience.
    #
    # @param key [String] The lookup key.
    # @param options [Hash] Options; see {.translate_x}.
    #
    # @return Returns the same type and value as `translate`.
    #
    # @raise if the translation lookup fails.

    def translate_x!(key, options={})
      translate_x(key, options.merge(:raise => true))
    end
    alias :tx! :translate_x!

    # @!scope class
    # Extend the functionality of I18n's `localize` method.
    # This method has the same call and return signature as `localize`, but it looks up locales from
    # {.locale_array} as described in the documentation header.
    #
    # Aliased to `lx` for convenience.
    #
    # @overload localize_x(object, options)
    #  @param object The object to localize.
    #  @param options [Hash] Options; these parameters take the same form as those for `localize`, with the
    #   following modifications:
    #
    #   - A scalar value for **:locale** in *options*, if present, is converted to a one-element array.
    #
    # @return Returns the same type and value as `localize`.

    def localize_x(object, locale: nil, format: nil, **options)
      locale ||= config.locale_array
      raise Disabled.new('t') if locale == false
      locale = [ locale ] unless locale.is_a?(Array)

      format ||= :default

      exc = nil
      locale.each do |loc|
        l = begin
              config.backend.localize(loc, object, format, options)
            rescue MissingTranslationData => x
              exc = x
            end
        return l unless l.is_a?(MissingTranslationData)
      end

      # if we made it here, there were no translations

      raise MissingTranslationData.new("[#{locale.join(',')}]", exc.key, options)
    end
    alias :lx :localize_x

    # @!scope class
    # Parse the Accept-Language HTTP header.
    # This method splits the Accept-Language HTTP header (if present) into an array containing
    # the locales listed in the header, sorted by their `q` value.
    #
    # @param request The current request object.
    #
    # @return Returns an array of strings containing the locales listed in Accept-Language,
    #  and sorted by descending `q` value. The locales are canonicalized: names are in lowercase, and 
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

  extend Fl

  module Base
    alias :_original_translate :translate
    alias :_original_localize :localize

    # @!scope class
    # Override I18n's `translate` method to call {.translate_x}. With this override, all I18N calls now use
    # the extended functionality.
    #
    # @overload translate(key, options)
    #  @param key [String] The lookup key.
    #  @param options [Hash] Options; see {.translate_x}. If the **:locale** option is not present, it defaults
    #   to the value of {.locale_array}.
    #
    # @return Returns the same type and value as the original implementation of `translate`.

    def translate(key = nil, *, throw: false, raise: false, locale: nil, **options) # TODO deprecate :raise
      locale ||= config.locale_array
      opts = options.merge(throw: throw, raise: raise, locale: locale)
      translate_x(key, **opts)
    end
    alias :t :translate

    # @!scope class
    # Override I18n's `localize` method to call {.localize_x}. With this override, all I18N calls now use
    # the extended functionality.
    #
    # @overload localize(object, options)
    #  @param object The object to localize.
    #  @param options [Hash] Options; see {.localize_x}. If the **:locale** option is not present, it defaults
    #   to the value of {.locale_array}.
    #
    # @return Returns the same type and value as the original implementation of `localize`.

    def localize(object, locale: nil, format: nil, **options)
      locale ||= config.locale_array
      opts = options.merge(locale: locale, format: format)
      localize_x(object, **opts)
    end
    alias :l :localize
  end
end

# Adds the `locale_array` pseudo-global property to the I18n Config object.

class I18n::Config
  # Gets the locale array.
  # This value is scoped to thread like `locale`.
  # It defaults to the array containing the `default_locale`.
  # 
  # @return [Array<Symbol>] Returns an array of locales.

  def locale_array
    (defined?(@locale_array) && (@locale_array != nil)) ? @locale_array : [ default_locale.to_sym ]
  end

  # Sets the current locale array pseudo-globally, i.e. in the `Thread.current` hash.
  #
  # @param locale_array [Array<Symbol, String>] An array of locale names; strings are converted to symbols.
  #
  # @return [Array<Symbol>] Returns the array of locales that was set.

  def locale_array=(locale_array)
    # for the time being we ignore the check
    # locale_array.each { |l| I18n.enforce_available_locales!(l) }
    @locale_array = locale_array.map { |l| l.to_sym }
  end
end

# Extensions to the ActionView module.

module ActionView
  # Extends the I18n proxy to implement `locale_array` and `locale_array=`.
  # This extension mimics the behaqvior of the `locale` and `locale=` methods in the I18n proxy.
  
  class I18nProxy < ::I18n::Config #:nodoc:
    # Accessor for the locales array.
    # Forwards the call to the underlying config object.
    #
    # @return [Array<Symbol>] Returns the locales as an array in order of preference.
    
    def locale_array
      @original_config.locale_array
    end

    # Setter for the locales array.
    # Forwards the call to the lookup context.
    #
    # @param value [Array<Symbol,String>] The locales as an array in order of preference.
    
    def locale_array=(value)
      @lookup_context.locale_array = value
    end
  end

  # Extends the ActiveView lookup context to implement `locale_array` and `locale_array=`.
  # This extension mimics the behaqvior of the `locale` and `locale=` methods in the lookup context.

  class LookupContext
    # Accessor for the locales array.
    #
    # @return [Array<Symbol>] Returns the locales as an array in order of preference.
    
    def locale_array
      @details[:locale_array]
    end

    # Setter for the locales array.
    # Forwards the call to the config object.
    #
    # @param value [Array<Symbol,String>] The locales as an array in order of preference.

    def locale_array=(value)
      if value
        config = I18n.config.respond_to?(:original_config) ? I18n.config.original_config : I18n.config
        config.locale_array = value
      end

      #      super(default_locale)
    end
  end

  # Extensions to the ActionView helpers module.

  module Helpers
    # Extends ActionView::Helpers::TranslationHelper with the I18n extensions.
    # The code template originated from actionview-6.0.3.4/lib/action_view/helpers/translation_helper.rb

    module TranslationHelper
      # Extended version of `translate` that uses the locale array instead of a single locale.
      # The arguments and return value are equivalent to those in `translate`.
      #
      # Aliased to `tx` for convenience.
      #
      # @param key [String] The lookup key.
      # @param options [Hash] Options; see {I18n.translate_x}.
      #
      # @return Returns the same type and value as {I18n.translate_x}.

      def translate_x(key, options = {})
        if options.has_key?(:default)
          remaining_defaults = Array.wrap(options.delete(:default)).compact
          options[:default] = remaining_defaults unless remaining_defaults.first.kind_of?(Symbol)
        end

        # If the user has explicitly decided to NOT raise errors, pass that option to I18n.
        # Otherwise, tell I18n to raise an exception, which we rescue further in this method.
        # Note: `raise_error` refers to us re-raising the error in this method. I18n is forced to raise by default.
        if options[:raise] == false
          raise_error = false
          i18n_raise = false
        else
          raise_error = options[:raise] || ActionView::Base.raise_on_missing_translations
          i18n_raise = true
        end

        if html_safe_translation_key?(key)
          html_safe_options = options.dup

          options.except(*I18n::RESERVED_KEYS).each do |name, value|
            unless name == :count && value.is_a?(Numeric)
              html_safe_options[name] = ERB::Util.html_escape(value.to_s)
            end
          end

          html_safe_options[:default] = MISSING_TRANSLATION unless html_safe_options[:default].blank?

          translation = I18n.translate_x(scope_key_by_partial(key), **html_safe_options.merge(raise: i18n_raise))

          if translation.equal?(MISSING_TRANSLATION)
            options[:default].first
          elsif translation.respond_to?(:map)
            translation.map { |element| element.respond_to?(:html_safe) ? element.html_safe : element }
          else
            translation.respond_to?(:html_safe) ? translation.html_safe : translation
          end
        else
          I18n.translate(scope_key_by_partial(key), **options.merge(raise: i18n_raise))
        end
      rescue I18n::MissingTranslationData => e
        if remaining_defaults.present?
          translate remaining_defaults.shift, **options.merge(default: remaining_defaults)
        else
          raise e if raise_error

          keys = I18n.normalize_keys(e.locale, e.key, e.options[:scope])
          title = +"translation missing: #{keys.join('.')}"

          interpolations = options.except(:default, :scope)
          if interpolations.any?
            title << ", " << interpolations.map { |k, v| "#{k}: #{ERB::Util.html_escape(v)}" }.join(", ")
          end

          return title unless ActionView::Base.debug_missing_translation

          content_tag("span", keys.last.to_s.titleize, class: "translation_missing", title: title)
        end
      end
      alias :tx :translate_x

      # Extended version of `localize` that uses the locale array instead of a single locale.
      # The arguments and return value are equivalent to those in `localize`.
      #
      # Aliased to `lx` for convenience.
      #
      # @param object [Object] The object to localize.
      # @param options [Hash] Options; see {I18n.localize}.
      #
      # @return Returns the same type and value as {I18n.localize_x}.

      def localize_x(object, **options)
        I18n.localize_x(object, **options)
      end
      alias :lx :localize_x

      alias :_original_translate :translate
      alias :t :translate_x
      alias :translate :translate_x

      alias :_original_localize :localize
      alias :t :localize_x
      alias :localize :localize_x
    end
  end
end

# Extensions of the AbstractController module.

module AbstractController
  # Extends AbstractController::Translation with the I18n extensions.
  # The code template originated from actionpack-6.0.3.4/lib/abstract_controller/translation.rb.

  module Translation
    # Extended version of `translate` that uses the locale array instead of a single locale.
    # The arguments and return value are equivalent to those in `translate`.
    #
    # Aliased to `tx` for convenience.
    #
    # @overload translate_x(key, options)
    #  @param key [String] The lookup key.
    #  @param options [Hash] Options; see {I18n.translate_x}.
    #
    # @return Returns the same type and value as {I18n.translate_x}.

    def translate_x(key, **options)
      if key.to_s.first == "."
        path = controller_path.tr("/", ".")
        defaults = [:"#{path}#{key}"]
        defaults << options[:default] if options[:default]
        options[:default] = defaults.flatten
        key = "#{path}.#{action_name}#{key}"
      end
      I18n.translate_x(key, **options)
    end
    alias :tx :translate_x

    # Extended version of `localize` that uses the locale array instead of a single locale.
    # The arguments and return value are equivalent to those in `localize`.
    #
    # Aliased to `lx` for convenience.
    #
    # @overload localize_x(object, options)
    #  @param object [Object] The object to localize.
    #  @param options [Hash] Options; see {I18n.localize}.
    #
    # @return Returns the same type and value as {I18n.localize}.

    def localize_x(object, **options)
      I18n.localize_x(object, **options)
    end
    alias :lx :localize_x

    alias :_original_translate :translate
    alias :t :translate_x
    alias :translate :translate_x

    alias :_original_localize :localize
    alias :t :localize_x
    alias :localize :localize_x
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
# `before_filter` to set up the locale array from the Accept-Language HTTP header.
# As a side effect, the I18n module is augmented with the I18n#translate_x method (and support APIs),
# and the `tx` method is added to the helpers, equivalently to the standard I18n `t` method.

module I18nExtension
  # Sets the I18n locale array from the Accept-Language HTTP header.
  # This method parses the Accept-Language header and sets the locale array appropriately.
  # Typically used as a `before_filter`:
  #
  # ```
  #  class ApplicationController < ActionController::Base
  #    include I18nExtension
  #    before_filter :set_locale_from_http_header
  #  end
  # ```
  #
  # Note if the `en` locale is not in the HTTP header, it is appended at the end of the array to provide
  # a failsafe backstop.

  def set_locale_from_http_header()
    loc = I18n.parse_accept_language(request)
    loc << 'en' unless loc.include?('en')
    I18n.locale_array = loc
  end
end
