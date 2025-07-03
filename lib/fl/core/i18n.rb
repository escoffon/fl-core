# Extend the functionality of Rails' I18n module to add support for the following functionality:
#
# * Look up from a list of locales, rather than from a single  The application can set an array
#   of locales, and the extension methods look up locales in the array order and return the first
#   translation hit. For example, if the locale array is <code>[ 'en_US', 'en', 'it', 'es' ]</code>, the
#   extension methods look up translations for `en_US`, `en`, `it`, and `es` until a match is found.
# * Adds the {.with_locale_array} to execute a block of code with custom locales.

module I18n
  module Base
    alias :_original_translate :translate
    alias :_original_localize :localize
  end
  
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
    # @param locale_array [Array<Symbol, String>] An array of locale names; the locale names are normalized.
    #
    # @return [Array<Symbol>] Returns the array of locales that was set.

    def locale_array=(locale_array)
      config.locale_array = locale_array.map { |l| I18n.normalize_locale(l) }
    end

    # @!scope class
    # Normalize a locale name.
    # Replaces dashes (`-`) with underscores (`_`), converts the language part to lowercase, and the region/variant
    # part to uppercase. For example, `en-US` is converted to `en_US`, and `en-us` to `en_US`; the normalized
    # format is consistent with common locale use, and specifically with how locales are defined in translation
    # files.
    #
    # @param locale [String,Symbol] The locale name.
    #
    # @return [String] Returns the normalized name.

    def normalize_locale(locale)
      idx = -1
      locale.to_s.gsub('-', '_').split('_').map do |l|
        idx += 1
        (idx == 0) ? l.downcase : l.upcase
      end.join('_')
    end

    # @!scope class
    # Normalize a list of locale names.
    # Calls {.normalize_locale} for each element of *locales* and returns the normalized values.
    #
    # @param locales [Array<String,Symbol>] The list of locale names.
    #
    # @return [Array<String>] Returns the list of normalized names.

    def normalize_locale_list(locales)
      locales = [ locales ] unless locales.is_a?(Array)

      return locales.map { |l| normalize_locale(l) }
    end

    # @!scope class
    # Inserts language-only locales in a list of locales.
    # This method scans *locales* for locale names that contain both language and region; if no corresponding
    # language-only locales are present, it inserts them in the list at appropriate location.
    # For example, if *locales* is `[ 'en-US', 'it-CH', 'es' ]`, the method returns
    # `[ 'en_US', 'en', 'it_CH', 'it', 'es' ]`.
    # However, with `[ 'en', 'en_US', 'it-CH` ]`, the return value is `[ 'en', 'en_US', 'it_CH', 'it' ]`, since
    # `'en'` is already in *locales*.
    #
    # This method is especially useful to handle requests from Safari on iOS, where the locale header typically
    # contains a single locale with both language and region (*e.g* `'it_IT'` or `en-US`).
    #
    # @param locales [Array<String,Symbol>] The locales array to process.
    #
    # @return [Array<String>] Returns the locales list, modified as described above.

    def expand_locales(locales)
      pos = { }
      explicit = { }
      locales.each_with_index do |loc, idx|
        dloc = loc.to_s.downcase
        lang = loc.to_s.split(/-_/).first
        pos[lang] = idx
        explicit[dloc] = idx
      end

      idx = 0
      locales.reduce([ ]) do |acc, loc|
        dloc = loc.to_s.downcase
        acc.push(loc)
        lang = dloc.to_s.split(/-_/).first
        acc.push(lang) if (lang != dloc) && (pos[lang] == idx) && !acc.include?(lang) && !explicit.has_key?(lang)
        idx += 1
        acc
      end
    end
    
    # @!scope class
    # Executes a block with a given locale array set.
    # This method sets the locale array, executes the block, and resets it to the original value.
    #
    # @param tmp_locale_array [Array<Symbol, String>,nil] An array of locale names; strings are converted to symbols.
    #  A `nil` value clears the locale array.
    #
    # @yield No parameters are passed to the block.
    #
    # @yieldreturn No value is expected from the block.
    
    def with_locale_array(tmp_locale_array = nil)
      if tmp_locale_array == nil
        yield
      else
        # The call to I18n.expand_locales is done mainly to address the behavior of Safari (and potentially other
        # browsers) on iOS. The list of locales is a single element containing both language and region (like it-it),
        # but Rails typically defines just the language translation files (like my.it.yml).
        # So we add the language-only locale so that Rails picks it up
        
        current_locale_array = self.locale_array
        current_locale = self.locale
        self.locale_array = I18n.expand_locales(tmp_locale_array)
        self.locale_array = self.locale_array + [ I18n.default_locale ] unless self.locale_array.include?(I18n.default_locale)
        loc = self.locale_array.find { |l| I18n.locale_available?(l) }
        self.locale = loc unless loc.nil?
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
    # @overload translate_x(key, **options)
    #  @param key [String,Symbol,Array<String,Symbol>] The lookup key. Pass an array to look up multiple keys.
    #  @param options [Hash] Options; these parameters take the same form as those for `translate`, with
    #   the following modifications:
    #
    #   - A scalar value for **:locale** in *options*, if present, is converted to a one-element array.
    #     If **:locale** is not present, use the value in {.locale_array}.
    #   - If **:default** is a string or a symbol, it is used for all keys in *key*.
    #     If it is an array, and its length is not the same as the length of *key*, then it is used as a list
    #     of alternatives to try for *all* keys.
    #     If it is an array, and its length is the same as the length of *key*, and each element is an array,
    #     then the element lists the alternatives to try for the corresponding entry in *key*.
    #     Otherwise, it is used as the list of alternatives to try for *all* keys.
    #
    #  Note that *key* and the **:default** option must be consistent with each other:
    #
    #  - If *key* is a scalar, **:default* can be a scalar or an array, but if the latter it may not contain
    #    arrays.
    #  - If *key* is an array, :default can be a scalar or an array, but if **:default** is an array, it is
    #    interpreted as outlined above.
    #
    #  So for a scalar *key*, the value of **:default** has the same semantics as for the original `translate`.
    #  For an array *key*, the value of **:default** has two interpretations: it is either a common set of
    #  defaults for the keys, or it lists separate defaults for each keys.
    #
    #  There is an ambiguity in situations where *key* is an array, you want to provide separate defaults,
    #  and one or more keys have a single default; in this case, make sure to specify the single default as
    #  a one element array.
    #  For example, if *key* is <code>[ 'k1', :k2 ]</code> and you want different backstop values for the two
    #  keys, set **:default** to <code>[ [ 'default for k1' ], [ 'default for k2' ] ]</code>.
    #  A value of <code>[ 'default for k1', 'default for k2' ]</code> is interpreted as a common set of
    #  defaults, and if both `:k1` and `:k2` cannot be resolved, the return value is
    #  <code>[ 'default for k1', 'default for k1' ]</code> instead of
    #  <code>[ 'default for k1', 'default for k2' ]</code>.
    #
    # @return Returns the same type and value as `translate`.

    def translate_x(key, **options)
      default = options[:default] || nil

      # an empty array for default is equivalent to no defaults; we can't leave it at that, since then the
      # outer loop won't iterate, so let's convert it to nil

      default = nil if default.is_a?(Array) && (default.count < 1)
      
      if key.is_a?(Array)
        use_default = _convert_defaults_for_key_array(key, default)
        idx = -1
        return key.map do |k|
          idx += 1
          o = { }.merge(options)
          o[:default] = use_default[idx] unless default.nil?
          
          translate_x(k, **o)
        end
      end
      
      locale = options[:locale] || I18n.locale_array
      locale = [ locale ] unless locale.is_a?(Array)

      # The implementation calls the original translate for each locale, returning the first hit.
      # In order to detect a successful translation, we force the :throw option to true and catch exceptions
      #
      # Additionally, if default is an array, we have to iterate over the array before we iterate over locales,
      # so that each default symbol has a shot at a lookup with all locales. So, we have the outer default loop,
      # and the inner locale loop. For example, if default is [ :key, 'backstop' ], and locale is [ :it, :en ],
      # then we have to try the :key for both :it and :en before moving on to 'backstop'.
      # if we were to loop over locales using [ :key, 'backstop' ], the original translate would return 'backstop'
      # at :it, without even trying for :en
      #
      # Note that a default value of [ :key1, 'backstop', :key2 ] would never try :key2, since 'backstop'
      # causes a successful return value ('backstop'). Similarly, with two string backstops, only the first one
      # is ever tried
      
      defaults = (default.is_a?(Array)) ? default : [ default ]
      locale_exceptions = [ ]
      translation = nil
      defaults.each_with_index do |df, df_idx|
        locale.each_with_index do |loc, loc_idx|
          begin
            o = { }.merge(options).merge(raise: true, throw: false).merge(locale: loc)
            o[:default] = df unless df.nil?
            t = _original_translate(key, **o)
          rescue StandardError => exc
            t = exc
          end

          if t.nil?
            # No translation
            
            locale_exceptions << t
          else
            case t
            when I18n::MissingTranslationData, I18n::MissingTranslation, I18n::InvalidLocaleData, I18n::InvalidLocale
              # we ignore these, but we push the exceptions on a stack for later use

              locale_exceptions << t
            when StandardError
              # all other exceptions get triggered up
          
              _signal_exception_array(false, [ t ], key, locale, **options)
            else
              # Typically, the return value here should be Sa string or a hash if the translation was found.
              # However, the ActionView::Helpers::TranslationHelper.translate method passes default: -(2**60)
              # in the call to I18n.translate, to detect a missing translation.
              # Therefore, this implementation must honor that return value, so that the ActionView helper
              # detects the missing translation and attempts to use the defaults (if any).
              # Therefore, any value of t that is not nil, an error, or one of the listed exceptions, is returned here

              translation = t
              break
            end
          end
        end

        break unless translation.nil?
      end

      if translation.nil?
        # OK, if we have no translation we need to figure out what to do, based on the options.
        # Note that _signal_exception_array may (likely will) throw or raise, and therefore not return
      
        return _signal_exception_array(false, locale_exceptions, key, locale, **options)
      else
        return translation
      end
    end
    alias :tx :translate_x
    
    # @!scope class
    # This version of {I18n::Fl.translate_x} sets the `:raise` option.
    #
    # Aliased to `tx!` for convenience.
    #
    # @param key [String] The lookup key.
    # @param options [Hash] Options; see {I18n::Fl.translate_x}.
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
        # note: some clients may generate the accept-language header with a starting locale with no q value,
        # then a bunch with q values, and then another bunch with no q values; I assume that the idea is that
        # that last bunch is the lowest priority, all at the same level. The AlamoFire request does, for example,
        # from the (very long) list of languages on the phone properties.
        # If we are not careful, those last locales end up looking like they are at q=1.0, and therefore sort
        # up instead of sorting down, so we track when q values have been seen
        
        did_see_q = false
        raw_locales = request.env['HTTP_ACCEPT_LANGUAGE'].split(',').map do |l|
          a = l.split(';')
          if a.length == 1
            [ a[0].strip, (did_see_q) ? 0.0 : 1.0 ]
          else
            if a[1] =~ /^\s*q=([01](\.[0-9])?)/i
              did_see_q = true
              d = Regexp.last_match
              [ a[0].strip, d[1].to_f ]
            else
              [ a[0].strip, (did_see_q) ? 0.0 : 1.0 ]
            end
          end
        end

        raw_locales.sort! { |e1, e2| e2[1] <=> e1[1] }
        return normalize_locale_list(raw_locales.map { |e| e[0].gsub('-', '_').downcase })
      else
        return [ config.locale ]
      end
    end
  end

  module FlHelpers
    private def _signal_exception_array(for_view, exc, key, locale, **options)
      if Rails::VERSION::MAJOR >= 7
        raise_error = options[:raise] || ActionView::Helpers::TranslationHelper.raise_on_missing_translations
        throw_error = options[:throw] || ActionView::Helpers::TranslationHelper.raise_on_missing_translations
      else
        raise_error = options[:raise] || ActionView::Helpers::TranslationHelper.raise_on_missing_translations
        throw_error = options[:throw] || ActionView::Helpers::TranslationHelper.raise_on_missing_translations
      end

      # We can only trigger one exception, so we go and pick the one that is used most (most likely, there
      # will be only one exception type

      exceptions = exc.reduce({ }) do |acc, x|
        k = x.class.name
        if acc.has_key?(k)
          acc[k] << x
        else
          acc[k] = [ x ]
        end

        acc
      end

      if exceptions.count == 1
        use_exception = exc.first
      else
        longest = exceptions.reduce([ ]) do |acc, kvp|
          n, x = kvp
          acc = x if x.count > acc.count
          acc
        end

        use_exception = longest.first
      end

      if use_exception.nil?
        return nil
      elsif raise_error
        raise use_exception
      elsif throw_error
        throw :exception, use_exception
      else
        # if no raise or throw is triggered, then we have to send back an error/status message.
        # If for_view is true, then this is a message to embed in a view; otherwise, it's a plain string

        if for_view
          return _missing_translation(key, options)
        else
          # The I18n.translate API uses the message generated by a I18n::MissingTranslation exception,
          # so let's generate it here. The only catch is that we have to manufacture a locale name that
          # includes the locales in the array

          return I18n::MissingTranslation.new("[#{locale.join(',')}]", key, **options).message
        end
      end
    end

    private def _convert_defaults_for_key_array(key, default)1
      # if :default is present, we have to determine what is actually passed down to each iteration.

      use_default = nil
      
      if default.is_a?(Array)
        if key.count != default.count
          # since the nuimber of keys is not the same as the number of defaults, we assume that these
          # are common defaults for all the keys

          use_default = Array.new(key.count, default)
        else
          # Same array size: look at the default array: if all elements are arrays, then we assume that they
          # are defaults for the corresponding key element.
          # If not all are arrays, then we use the default array as common defaults.
          # If you want to provide a single default per element, pass it as a one-element array

          array_count = default.reduce(0) do |acc, df|
            acc += 1 if df.is_a?(Array)
            acc
          end

          if array_count == default.count
            use_default = default
          else
            use_default = Array.new(key.count, default)
          end
        end
      elsif !default.nil?
        use_default = Array.new(key.count, default)
      end

      return use_default
    end
 
    private def _missing_translation(key, options)
      # The body of this method is slightly modified from ActionView::Helpers::TRanslationHelper.missing_translation
      # since we need to account for multiple locales

      locale = options[:locale] || I18n.locale_array
      locale = [ locale ] unless locale.is_a?(Array)
      
      keys = I18n.normalize_keys("[#{locale.join(',')}]", key, options[:scope])

      title = +"translation missing: #{keys.join(".")}"

      options.each do |name, value|
        unless name == :scope
          title << ", " << name.to_s << ": " << ERB::Util.html_escape(value)
        end
      end

      if ActionView::Base.debug_missing_translation
        content_tag("span", keys.last.to_s.titleize, class: "translation_missing", title: title)
      else
        title
      end
    end
  end
  
  extend Fl
  extend FlHelpers
  
  module Base
    # @!scope class
    # Override I18n's `translate` method to call {I18n::Fl.translate_x}. With this override, all I18N calls now use
    # the extended functionality.
    #
    # @overload translate(key, options)
    #  @param key [String] The lookup key.
    #  @param options [Hash] Options; see {I18n::Fl.translate_x}. If the **:locale** option is not present, it defaults
    #   to the value of {.locale_array}.
    #
    # @return Returns the same type and value as the original implementation of `translate`.

    def translate(key, **options)
      translate_x(key, **options)
    end
    alias :t :translate

    # @!scope class
    # Override I18n's `localize` method to call {I18n::Fl.localize_x}. With this override, all I18N calls now use
    # the extended functionality.
    #
    # @overload localize(object, options)
    #  @param object The object to localize.
    #  @param options [Hash] Options; see {I18n::Fl.localize_x}. If the **:locale** option is not present, it defaults
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
      include I18n::FlHelpers

      alias :_original_translate :translate

      # Extended version of `translate` that uses the locale array instead of a single locale.
      # The arguments and return value are equivalent to those in `translate`.
      #
      # Aliased to `tx` for convenience.
      #
      # @param key [String] The lookup key.
      # @param options [Hash] Options; see {I18n::Fl.translate_x}.
      #
      # @return Returns the same type and value as {I18n::Fl.translate_x}.

      def translate_x(key, **options)
        default = options[:default] || nil

        # an empty array for default is equivalent to no defaults; we can't leave it at that, since then the
        # outer loop won't iterate, so let's convert it to nil

        default = nil if default.is_a?(Array) && (default.count < 1)
      
        if key.is_a?(Array)
          use_default = _convert_defaults_for_key_array(key, default)
          idx = -1
          return key.map do |k|
            idx += 1
            o = { }.merge(options)
            o[:default] = use_default[idx] unless default.nil?
          
            translate_x(k, **o)
          end
        end
      
        locale = options[:locale] || I18n.locale_array
        locale = [ locale ] unless locale.is_a?(Array)

        # The implementation calls the original translate for each locale, returning the first hit.
        # In order to detect a successful translation, we force the :throw option to true and catch exceptions
        #
        # Additionally, if default is an array, we have to iterate over the array before we iterate over locales,
        # so that each default symbol has a shot at a lookup with all locales. So, we have the outer default loop,
        # and the inner locale loop. For example, if default is [ :key, 'backstop' ], and locale is [ :it, :en ],
        # then we have to try the :key for both :it and :en before moving on to 'backstop'.
        # if we were to loop over locales using [ :key, 'backstop' ], the original translate would return 'backstop'
        # at :it, without even trying for :en
        #
        # Note that a default value of [ :key1, 'backstop', :key2 ] would never try :key2, since 'backstop'
        # causes a successful return value ('backstop'). Similarly, with two string backstops, only the first one
        # is ever tried
      
        defaults = (default.is_a?(Array)) ? default : [ default ]
        locale_exceptions = [ ]
        translation = nil
        defaults.each_with_index do |df, df_idx|
          locale.each_with_index do |loc, loc_idx|
            begin
              o = { }.merge(options).merge(raise: true, throw: false).merge(locale: loc)
              o[:default] = df unless df.nil?
              t = _original_translate(key, **o)
            rescue StandardError => exc
              t = exc
            end

            if t.nil?
              locale_exceptions << t
            else
              case t
              when I18n::MissingTranslationData, I18n::MissingTranslation, I18n::InvalidLocaleData, I18n::InvalidLocale
                # we ignore these, but we push the exceptions on a stack for later use

                locale_exceptions << t
              when StandardError
                # all other exceptions get triggered up
          
                _signal_exception_array(true, [ t ], key, locale, **options)
              when String, Hash
                # This is the translation

                translation = t
                break
              end
            end
          end

          break unless translation.nil?
        end

        if translation.nil?
          # OK, if we have no translation we need to figure out what to do, based on the options.
          # Note that _signal_exception_array may (likely will) throw or raise, and therefore not return
      
          return _signal_exception_array(true, locale_exceptions, key, locale, **options)
        else
          return translation
        end
      end
      alias :tx :translate_x

      # Extended version of `localize` that uses the locale array instead of a single locale.
      # The arguments and return value are equivalent to those in `localize`.
      #
      # Aliased to `lx` for convenience.
      #
      # @param object [Object] The object to localize.
      # @param options [Hash] Options; see {I18n::Base.localize}.
      #
      # @return Returns the same type and value as {I18n::Fl.localize_x}.

      def localize_x(object, **options)
        I18n.localize_x(object, **options)
      end
      alias :lx :localize_x

      alias :t :translate_x
      alias :translate :translate_x

      alias :_original_localize :localize
      alias :l :localize_x
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
    #  @param options [Hash] Options; see {I18n::Fl.translate_x}.
    #
    # @return Returns the same type and value as {I18n::Fl.translate_x}.

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
    #  @param options [Hash] Options; see {I18n::Base.localize}.
    #
    # @return Returns the same type and value as {I18n::Base.localize}.

    def localize_x(object, **options)
      I18n.localize_x(object, **options)
    end
    alias :lx :localize_x

    alias :_original_translate :translate
    alias :t :translate_x
    alias :translate :translate_x

    alias :_original_localize :localize
    alias :l :localize_x
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
