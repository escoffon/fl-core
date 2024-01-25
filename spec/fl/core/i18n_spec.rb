RSpec.describe I18n do
  before(:example) do
    I18n.locale_array = [ :en ]
  end
  
  let(:dt1) { Time.new(2020, 2, 10, 10, 20, 30) }
  let(:dt2) { Time.new(2022, 4, 20, 12, 22, 32) }

  def _sym(l)
    l.map { |e| e.to_sym }
  end

  def _missing(locale, key, **options)
    locale = I18n.locale_array if locale.nil?
    if locale.is_a?(Array)
      return I18n::MissingTranslation.new("[#{locale.join(',')}]", key, **options).message
    else
      return I18n::MissingTranslation.new(locale, key, **options).message
    end
  end
  
  describe '.locale_array=' do
    it 'should set the array' do
      nl = [ :it, :en ]
      I18n.locale_array = nl
      expect(I18n.locale_array).to eql([ :it, :en ])
    end

    it 'should convert locales to symbols' do
      nl = [ 'it', 'en' ]
      I18n.locale_array = nl
      expect(I18n.locale_array).to eql([ :it, :en ])
    end

    it 'should normalize locale names' do
      I18n.locale_array = [ 'EN', 'it_it', 'en-nz', 'EN-GB' ]
      expect(I18n.locale_array).to eql([ 'en', 'it-IT', 'en-NZ', 'en-GB' ].map { |l| l.to_sym })
    end
  end

  describe '.normalize_locale' do
    it 'should normalize a simple locale name' do
      expect(I18n.normalize_locale('en')).to eql('en')
      expect(I18n.normalize_locale('EN')).to eql('en')
    end

    it 'should normalize a complex locale name' do
      expect(I18n.normalize_locale('en-US')).to eql('en-US')
      expect(I18n.normalize_locale('EN-US')).to eql('en-US')
      expect(I18n.normalize_locale('en-us')).to eql('en-US') 

      expect(I18n.normalize_locale('en-US-SW')).to eql('en-US-SW')
      expect(I18n.normalize_locale('EN-US-sw')).to eql('en-US-SW')
      expect(I18n.normalize_locale('en-us-sw')).to eql('en-US-SW') 
   end

    it 'should convert underscores to dashes' do
      expect(I18n.normalize_locale('en_US')).to eql('en-US')
      expect(I18n.normalize_locale('en_us')).to eql('en-US')

      expect(I18n.normalize_locale('en_US_sw')).to eql('en-US-SW')
      expect(I18n.normalize_locale('en_us_sw')).to eql('en-US-SW')
    end
  end

  describe '.expand_locales' do
    it 'should insert a language-only locale if needed' do
      expect(I18n.expand_locales([ 'en-US', 'en-NZ', 'it-IT' ])).to eql([ 'en-US', 'en-NZ', 'en', 'it-IT', 'it' ])
    end

    it 'should not insert a language-only locale if one is already present' do
      expect(I18n.expand_locales([ 'en', 'en-US', 'en-NZ', 'it-IT' ])).to eql([ 'en', 'en-US', 'en-NZ', 'it-IT', 'it' ])
      expect(I18n.expand_locales([ 'en-US', 'en', 'en-NZ', 'it-IT' ])).to eql([ 'en-US', 'en', 'en-NZ', 'it-IT', 'it' ])
      expect(I18n.expand_locales([ 'en-US', 'en-NZ', 'en', 'it-IT' ])).to eql([ 'en-US', 'en-NZ', 'en', 'it-IT', 'it' ])
      expect(I18n.expand_locales([ 'en-US', 'en-NZ', 'it-IT', 'en' ])).to eql([ 'en-US', 'en-NZ', 'it-IT', 'it', 'en' ])
    end
  end
  
  describe '.translate_x' do
    it 'should accept defaults' do
      I18n.locale_array = [ :it, :en ]
      
      expect(I18n.translate_x('msg1')).to eql('IT message 1')
      expect(I18n.translate_x('base.msg2')).to eql('EN base.message 2')
      expect(I18n.translate_x('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(I18n.translate_x('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should be aliased to :tx' do
      I18n.locale_array = [ :it, :en ]
      
      expect(I18n.tx('msg1')).to eql('IT message 1')
      expect(I18n.tx('base.msg2')).to eql('EN base.message 2')
      expect(I18n.tx('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(I18n.tx('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should be aliased to :translate' do
      I18n.locale_array = [ :it, :en ]
      
      expect(I18n.translate('msg1')).to eql('IT message 1')
      expect(I18n.translate('base.msg2')).to eql('EN base.message 2')
      expect(I18n.translate('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(I18n.translate('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should be aliased to :t' do
      I18n.locale_array = [ :it, :en ]
      
      expect(I18n.t('msg1')).to eql('IT message 1')
      expect(I18n.t('base.msg2')).to eql('EN base.message 2')
      expect(I18n.t('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(I18n.t('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should return nil on a nil key' do
      expect(I18n.tx(nil)).to be_nil
    end

    it 'should return a message with an invalid locale' do
      I18n.locale_array = [ :xx ]
        
      t = I18n.tx('msg1')
      expect(t).to be_a(String)
      expect(t).to eql(_missing(nil, 'msg1'))
    end

    it 'should support the :default option' do
      expect(I18n.tx('missing', default: 'default value')).to eql('default value')
      expect(I18n.tx(:missing, default: 'base.msg1'.to_sym)).to eql('EN base.message 1')
    end

    it 'should translate arrays of keys' do
      expect(I18n.translate_x([ 'msg1', 'base.msg1' ])).to eql([ 'EN message 1', 'EN base.message 1' ])
    end

    it 'should return hashes for non-leaf nodes' do
      t = I18n.tx('base.sub')
      expect(t).to eql({
                         msg2: "EN base.sub.message 2",
                         msg3: "EN base.sub.message 3",
                         html: "<b>EN base.sub.html</b>",
                         unsafe: "<b>EN base.sub.unsafe</b>",
                         subsub: {
                           msg3: "EN base.sub.subsub.message 3",
                           msg4: "EN base.sub.subsub.message 4",
                           html: "<b>EN base.sub.subsub.html</b>"
                         }
                       })
    end

    it 'should accept the :locale option' do
      expect(I18n.tx('msg1', locale: :it)).to eql('IT message 1')
      expect(I18n.tx('base.msg1', locale: 'it')).to eql('IT base.message 1')
      expect(I18n.tx('base.sub.msg2', locale: :it)).to eql('IT base.sub.message 2')
      expect(I18n.tx('base.sub.subsub.msg4', locale: 'it')).to eql('IT base.sub.subsub.message 4')

      expect(I18n.translate_x('msg1', locale: [ :it, 'en' ])).to eql('IT message 1')
      expect(I18n.translate_x('base.msg2', locale: [ :it, 'en' ])).to eql('EN base.message 2')

      expect(I18n.translate_x([ 'msg1', 'base.msg2' ],
                              locale: [ :it, 'en' ])).to eql([ 'IT message 1', 'EN base.message 2' ])

      t = I18n.tx('base.sub', locale: 'it')
      expect(t).to eql({
                         msg2: "IT base.sub.message 2",
                         html: "<b>IT base.sub.html</b>",
                         unsafe: "<b>IT base.sub.unsafe</b>",
                         subsub: {
                           msg4: "IT base.sub.subsub.message 4"
                         }
                       })
    end

    it 'should accept the :scope option' do
      expect(I18n.tx('msg3', scope: 'base.sub.subsub')).to eql('EN base.sub.subsub.message 3')
      expect(I18n.tx('msg3', scope: [ 'base', 'sub', 'subsub' ])).to eql('EN base.sub.subsub.message 3')
      expect(I18n.tx([ 'msg3', 'msg2' ],
                     scope: [ 'base', 'sub' ])).to eql([ 'EN base.sub.message 3', 'EN base.sub.message 2' ])

      expect(I18n.tx('msg2', scope: [ :base, 'sub' ])).to eql('EN base.sub.message 2')
      expect(I18n.tx('msg2', scope: 'base.sub')).to eql('EN base.sub.message 2')
    end

    it 'should return a standard message on a missing translation' do
      t = I18n.tx('missing')
      expect(t).to be_a(String)
      expect(t).to eql(_missing(nil, 'missing'))
    end

    it 'should accept the :raise option' do
      expect do
        I18n.tx('missing', raise: true)
      end.to raise_exception(I18n::MissingTranslationData)
    end

    it 'should accept the :throw option' do
      expect do
        I18n.tx('missing', throw: true)
      end.to throw_symbol(:exception)

      exc = catch(:exception) do
        I18n.tx('missing', throw: true)
      end
      expect(exc).to be_a(I18n::MissingTranslationData)
    end

    context 'with multiple locales' do
      it 'should traverse the locales array' do
        I18n.locale_array = [ :it, :en ]
      
        expect(I18n.translate_x('msg1')).to eql('IT message 1')
        expect(I18n.translate_x('base.msg1')).to eql('IT base.message 1')
        expect(I18n.translate_x('base.msg2')).to eql('EN base.message 2')
        expect(I18n.translate_x('base.sub.msg2')).to eql('IT base.sub.message 2')
        expect(I18n.translate_x('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
      end

      it 'should accept an array value for :locale' do
        expect(I18n.translate_x('msg1', locale: [ :it, :en ])).to eql('IT message 1')
        expect(I18n.translate_x('base.msg1', locale: [ :it, :en ])).to eql('IT base.message 1')
        expect(I18n.translate_x('base.msg2', locale: [ :it, :en ])).to eql('EN base.message 2')
        expect(I18n.translate_x('base.sub.msg2', locale: [ :it, :en ])).to eql('IT base.sub.message 2')
        expect(I18n.translate_x('base.sub.subsub.msg3', locale: [ :it, :en ])).to eql('EN base.sub.subsub.message 3')
      end

      it 'should translate arrays of keys' do
        I18n.locale_array = [ :it, :en ]
      
        expect(I18n.translate_x([ 'base.msg1', 'base.msg2' ])).to eql([ 'IT base.message 1', 'EN base.message 2' ])
      end

      it 'should not raise on unsupported locales' do
        I18n.locale_array = [ :xx, :it, :en ]
      
        expect(I18n.translate_x('msg1')).to eql('IT message 1')
        expect(I18n.translate_x('base.msg1')).to eql('IT base.message 1')

        # Does not raise because it finds an :it translation
        expect(I18n.tx('msg1', raise: true)).to eql('IT message 1')
      end

      it 'should raise on a single unsupported locale' do
        I18n.locale_array = [ :xx ]
      
        expect do
          I18n.translate_x('msg1', raise: true)
        end.to raise_exception(I18n::InvalidLocale)
      end

      it 'should return a message with an array of unsupported locales' do
        I18n.locale_array = [ :xx, :yy ]
      
        t = I18n.tx('msg1')
        expect(t).to be_a(String)
        expect(t).to eql(_missing(nil, 'msg1'))
      
        expect do
          I18n.tx('msg1', raise: true)
        end.to raise_exception(I18n::InvalidLocale)

        exc = nil
        begin
          I18n.tx('msg1', raise: true)
        rescue I18n::InvalidLocale => x
          exc = x
        end
        expect(exc.message).to start_with(':xx ')

        expect do
          I18n.tx('msg1', throw: true)
        end.to throw_symbol(:exception)

        exc = catch(:exception) do
          I18n.tx('msg1', throw: true)
        end
        expect(exc).to be_a(I18n::InvalidLocale)
        expect(exc.message).to start_with(':xx ')
      end
    end

    context 'with the :default option' do
      it 'should accept a plain string' do
        expect(I18n.tx('not.a.key', default: 'default value')).to eql('default value')
        expect(I18n.tx([ 'not.a.key', 'no2' ], default: 'default value')).to eql([ 'default value', 'default value' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], default: 'default value')).to eql([ 'default value', 'EN message 1' ])
      end

      it 'should accept a symbol for an alternate key' do
        expect(I18n.tx('not.a.key', default: 'base.msg1'.to_sym)).to eql('EN base.message 1')
        expect(I18n.tx([ 'not.a.key', 'no2' ],
                       default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN base.message 1' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ],
                       default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN message 1' ])
      end

      it 'should accept a scalar default for a single key' do
        expect(I18n.tx('not.a.key',
                       default: 'base.msg1'.to_sym )).to eql('EN base.message 1')
        expect(I18n.tx('not.a.key', default: 'backstop')).to eql('backstop')
      end

      it 'should accept an array of defaults for a single key' do
        expect(I18n.tx('not.a.key',
                       default: [ 'base.msg1'.to_sym ])).to eql('EN base.message 1')
        expect(I18n.tx('not.a.key',
                       default: [ 'base.msg10'.to_sym, 'backstop' ])).to eql('backstop')
        expect(I18n.tx('not.a.key',
                       locale: [ :it, :en ],
                       default: [ 'base.msg1'.to_sym, 'backstop' ])).to eql('IT base.message 1')
        expect(I18n.tx('not.a.key',
                       locale: [ :it, :en ],
                       default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql('EN base.message 2')
      end

      it 'should give priority to alternate keys over strings' do
        I18n.locale_array = [ :it, :en ]
        
        expect(I18n.tx('not.a.key',
                       default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql('EN base.message 2')
      end

      context 'with multiple keys' do
        it 'should accept a common scalar default' do
          expect(I18n.tx([ 'not.a.key', 'no2' ],
                         default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN base.message 1' ])
          expect(I18n.tx([ 'not.a.key', 'msg1' ],
                         default: 'backstop')).to eql([ 'backstop', 'EN message 1' ])
        end

        it 'uses common defaults if array lengths are not the same' do
          expect(I18n.tx([ 'not.a.key', 'no2', 'no3' ],
                         default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                                'EN base.message 2',
                                                                                'EN base.message 2' ])
          expect(I18n.tx([ 'not.a.key', 'no2', 'no3' ],
                         locale: [ :it, :en ],
                         default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                                'EN base.message 2',
                                                                                'EN base.message 2' ])
          I18n.locale_array = [ :it ]
          expect(I18n.tx([ 'not.a.key', 'no2', 'no3' ],
                         default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'backstop',
                                                                                'backstop',
                                                                                'backstop' ])
        end

        it 'uses custom defaults if same array length and all elements are arrays' do
          expect(I18n.tx([ 'not.a.key', 'no2' ],
                         default: [
                           [ 'base.msg2'.to_sym, 'backstop' ],
                           [ 'base.msg1'.to_sym, 'default' ]
                         ])).to eql([ 'EN base.message 2',
                                      'EN base.message 1' ])

          expect(I18n.tx([ 'not.a.key', 'no2', 'no3' ],
                         locale: [ :it, :en ],
                         default: [
                           [ 'base.msg2'.to_sym, 'backstop' ],
                           [ 'base.msg1'.to_sym, 'default' ],
                           [ 'no3 default' ]
                         ])).to eql([ 'EN base.message 2',
                                      'IT base.message 1',
                                      'no3 default' ])

          expect(I18n.tx([ 'not.a.key', 'no2', 'base.msg12', 'base.msg1' ],
                         locale: [ :it, :en ],
                         default: [
                           [ 'base.msg2'.to_sym, 'backstop' ],
                           [ 'base.msg1'.to_sym, 'default 1' ],
                           [ 'base.msg12 default' ],
                           [ 'base.msg1'.to_sym, 'default 2' ]
                         ])).to eql([ 'EN base.message 2',
                                      'IT base.message 1',
                                      'base.msg12 default',
                                      'IT base.message 1' ])
        end

        it 'uses common defaults if same array length and not all elements are arrays' do
          expect(I18n.tx([ 'not.a.key', 'no2' ],
                         default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                                'EN base.message 2' ])

          I18n.locale_array = [ :it, :en ]
          expect(I18n.tx([ 'not.a.key', 'no2' ],
                         default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                                'EN base.message 2' ])

          expect(I18n.tx([ 'not.a.key', 'no2' ],
                         locale: [ :it, :en ],
                         default: [ 'base.msg20'.to_sym, 'backstop' ])).to eql([ 'backstop',
                                                                                 'backstop' ])
        end
      end
    end

    context 'on a missing translation' do
      it 'should return an error string by default' do
        key = 'not.a.key'
        expect(I18n.tx(key)).to eql(_missing(nil, key))

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        t = I18n.tx(key)
        expect(t[0]).to eql('EN message 1')
        expect(t[1]).to eql(_missing(nil, key[1]))
        expect(t[2]).to eql('EN base.message 1')
      end

      it 'should raise an exception if configured' do
        key = 'not.a.key'
        expect do
          I18n.tx(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          I18n.tx(key, raise: true)
        rescue I18n::MissingTranslationData => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to eql(_missing(:en, key))

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect do
          I18n.tx(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          I18n.tx(key, raise: true)
        rescue I18n::MissingTranslationData => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to eql(_missing(:en, 'not.a.key'))
      end

      it 'should throw a symbol if configured' do
        key = 'not.a.key'
        expect do
          I18n.tx(key, throw: true)
        end.to throw_symbol(:exception)

        exc = catch(:exception) do
          I18n.tx(key, throw: true)
        end
        expect(exc).to be_a(I18n::MissingTranslationData)

        expect do
          I18n.tx(key, throw: :foo)
        end.to throw_symbol(:exception)

        exc = catch(:exception) do
          I18n.tx(key, throw: :foo)
        end
        expect(exc).to be_a(I18n::MissingTranslationData)

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect do
          I18n.tx(key, throw: true)
        end.to throw_symbol(:exception)

        exc = catch(:exception) do
          I18n.tx(key, throw: true)
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
      end
    end
  end

  describe '.translate' do
    it 'should implement the translate_x functionality' do
      expect(I18n.translate('msg1')).to eql('EN message 1')

      expect(I18n.t([ 'msg1', 'base.msg1' ])).to eql([ 'EN message 1', 'EN base.message 1' ])

      expect(I18n.translate('msg1', locale: [ :it, 'en' ])).to eql('IT message 1')
      expect(I18n.t('base.msg2', locale: [ :it, 'en' ])).to eql('EN base.message 2')

      expect(I18n.t([ 'msg1', 'base.msg2' ],
                    locale: [ :it, 'en' ])).to eql([ 'IT message 1', 'EN base.message 2' ])
    end
    
    it 'should return nil on a nil key' do
      expect(I18n.t(nil)).to be_nil
    end

    context 'with the :default option' do
      it 'should accept a plain string' do
        expect(I18n.t('not.a.key', default: 'default value')).to eql('default value')
        expect(I18n.t([ 'not.a.key', 'no2' ], default: 'default value')).to eql([ 'default value', 'default value' ])
        expect(I18n.t([ 'not.a.key', 'msg1' ], default: 'default value')).to eql([ 'default value', 'EN message 1' ])
      end

      it 'should accept a symbol for an alternate key' do
        expect(I18n.t('not.a.key', default: 'base.msg1'.to_sym)).to eql('EN base.message 1')
        expect(I18n.t([ 'not.a.key', 'no2' ],
                      default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN base.message 1' ])
        expect(I18n.t([ 'not.a.key', 'msg1' ],
                      default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN message 1' ])
      end

      it 'should accept an array of defaults' do
        expect(I18n.t('not.a.key',
                      default: [ 'base.msg1'.to_sym ])).to eql('EN base.message 1')
        expect(I18n.t([ 'not.a.key', 'no2' ],
                      default: [ 'base.msg1'.to_sym ])).to eql([ 'EN base.message 1', 'EN base.message 1' ])
        expect(I18n.t([ 'not.a.key', 'msg1' ],
                      default: [ 'base.msg1'.to_sym ])).to eql([ 'EN base.message 1', 'EN message 1' ])

        expect(I18n.t('not.a.key',
                      default: [ 'base.msg10'.to_sym, 'backstop' ])).to eql('backstop')
        expect(I18n.t([ 'not.a.key', 'no2' ],
                      default: [ 'base.msg10'.to_sym, 'backstop' ])).to eql([ 'backstop', 'backstop' ])
        expect(I18n.t([ 'not.a.key', 'msg1' ],
                      default: [ 'base.msg10'.to_sym, 'backstop' ])).to eql([ 'backstop', 'EN message 1' ])
      end
    end
    
    context 'on a missing translation' do
      it 'should return an error string by default' do
        key = 'not.a.key'
        expect(I18n.t(key)).to eql(_missing([ :en ], 'not.a.key'))

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        t = I18n.t(key)
        expect(t[0]).to eql('EN message 1')
        expect(t[1]).to eql(_missing([ :en ], 'not.a.key'))
        expect(t[2]).to eql('EN base.message 1')
      end

      it 'should raise an exception if configured' do
        key = 'not.a.key'
        expect do
          I18n.t(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          I18n.t(key, raise: true)
        rescue I18n::MissingTranslationData => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to eql(_missing(:en, key))

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect do
          I18n.t(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          I18n.t(key, raise: true)
        rescue I18n::MissingTranslationData => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to eql(_missing(:en, 'not.a.key'))
      end

      it 'should throw a symbol if configured' do
        key = 'not.a.key'
        expect do
          I18n.t(key, throw: true)
        end.to throw_symbol(:exception)

        exc = catch(:exception) do
          I18n.t(key, throw: true)
        end
        expect(exc).to be_a(I18n::MissingTranslationData)

        expect do
          I18n.t(key, throw: :foo)
        end.to throw_symbol(:exception)

        exc = catch(:exception) do
          I18n.t(key, throw: :foo)
        end
        expect(exc).to be_a(I18n::MissingTranslationData)

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect do
          I18n.t(key, throw: true)
        end.to throw_symbol(:exception)

        exc = catch(:exception) do
          I18n.t(key, throw: true)
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to eql(_missing(:en, 'not.a.key'))
      end
    end
  end

  describe '.localize_x' do
    it 'should localize a known format' do
      expect(I18n.localize_x(dt1, format: :year)).to eql('EN year: 2020')
    end

    it 'should alias to lx' do
      expect(I18n.lx(dt1, format: :year)).to eql('EN year: 2020')
    end

    it 'should process the :locale option' do
      expect(I18n.lx(dt1, format: :year, locale: [ 'it', 'en' ])).to eql('IT year: 2020')
    end

    it 'should look up translations in all available locales' do
      expect do
        I18n.lx(dt1, format: :day, locale: [ 'it' ])
      end.to raise_exception(I18n::MissingTranslationData)
      
      expect(I18n.lx(dt1, format: :day, locale: [ 'it', 'en' ])).to eql('EN day: 10')
    end
    
    it 'should raise on an unknown format' do
      expect do
        I18n.localize_x(dt1, format: :unknown)
      end.to raise_exception(I18n::MissingTranslationData)

      x = nil
      begin
        I18n.localize_x(dt1, format: :unknown)
      rescue Exception => xx
        x = xx
      end
      expect(x.message).to start_with('Translation missing: [en].time.formats.unknown')
      expect(x.key).to eql('time.formats.unknown'.to_sym)

      expect do
        I18n.localize_x(dt1, format: :unknown, locale: [ 'it', 'en' ])
      end.to raise_exception(I18n::MissingTranslationData)

      x = nil
      begin
        I18n.localize_x(dt1, format: :unknown, locale: [ 'it', 'en' ])
      rescue Exception => xx
        x = xx
      end
      expect(x.message).to start_with('Translation missing: [it,en].time.formats.unknown')
      expect(x.key).to eql('time.formats.unknown'.to_sym)
    end
  end

  describe '.localize' do
    it 'should localize a known format' do
      expect(I18n.localize(dt1, format: :year)).to eql('EN year: 2020')
    end

    it 'should process the :locale option' do
      expect(I18n.l(dt1, format: :year, locale: [ 'it', 'en' ])).to eql('IT year: 2020')
    end

    it 'should look up translations in all available locales' do
      expect do
        I18n.l(dt1, format: :day, locale: [ 'it' ])
      end.to raise_exception(I18n::MissingTranslationData)
      
      expect(I18n.lx(dt1, format: :day, locale: [ 'it', 'en' ])).to eql('EN day: 10')
    end
    
    it 'should raise on an unknown format' do
      expect do
        I18n.localize(dt1, format: :unknown)
      end.to raise_exception(I18n::MissingTranslationData)

      x = nil
      begin
        I18n.localize(dt1, format: :unknown)
      rescue Exception => xx
        x = xx
      end
      expect(x.message).to start_with('Translation missing: [en].time.formats.unknown')
      expect(x.key).to eql('time.formats.unknown'.to_sym)

      expect do
        I18n.localize(dt1, format: :unknown, locale: [ 'it', 'en' ])
      end.to raise_exception(I18n::MissingTranslationData)

      x = nil
      begin
        I18n.localize(dt1, format: :unknown, locale: [ 'it', 'en' ])
      rescue Exception => xx
        x = xx
      end
      expect(x.message).to start_with('Translation missing: [it,en].time.formats.unknown')
      expect(x.key).to eql('time.formats.unknown'.to_sym)
    end
  end

  describe '.with_locale_array' do
    it 'should normalize locale names' do
      I18n.with_locale_array([ 'EN', 'it_it', 'en-nz', 'EN-GB' ]) do
        expect(I18n.locale_array).to eql(_sym([ 'en', 'it-IT', 'en-NZ', 'en-GB' ]))
      end
    end

    it 'should set .locale to the first valid one in the list' do
      I18n.with_locale_array([ 'it-CH', 'it', 'en' ]) do
        expect(I18n.locale).to eql(:it)
      end
    end

    it 'should append the default locale if not already present' do
      I18n.with_locale_array([ 'it', 'en-US' ]) do
        expect(I18n.locale_array).to eql(_sym([ 'it', 'en-US', 'en' ]))
      end
    end

    it 'should insert language-only locales as needed' do
      I18n.with_locale_array([ 'en-US', 'en-NZ', 'it-IT' ]) do
        expect(I18n.locale_array).to eql(_sym([ 'en-US', 'en-NZ', 'en', 'it-IT', 'it' ]))
      end

      I18n.with_locale_array([ 'en', 'en-US', 'en-NZ', 'it-IT' ]) do
        expect(I18n.locale_array).to eql(_sym([ 'en', 'en-US', 'en-NZ', 'it-IT', 'it' ]))
      end
      
      I18n.with_locale_array([ 'en-US', 'en', 'en-NZ', 'it-IT' ]) do
        expect(I18n.locale_array).to eql(_sym([ 'en-US', 'en', 'en-NZ', 'it-IT', 'it' ]))
      end
      
      I18n.with_locale_array([ 'en-US', 'en-NZ', 'en', 'it-IT' ]) do
        expect(I18n.locale_array).to eql(_sym([ 'en-US', 'en-NZ', 'en', 'it-IT', 'it' ]))
      end
      
      I18n.with_locale_array([ 'en-US', 'en-NZ', 'it-IT', 'en' ]) do
        expect(I18n.locale_array).to eql(_sym([ 'en-US', 'en-NZ', 'it-IT', 'it', 'en' ]))
      end
    end

    it 'should set locales for .translate_x' do
      expect(I18n.translate_x('msg1')).to eql('EN message 1')

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.translate_x('msg1')).to eql('IT message 1')
      end

      I18n.with_locale_array([ 'en', 'it' ]) do
        expect(I18n.translate_x('msg1')).to eql('EN message 1')
      end

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.translate_x('base.msg2')).to eql('EN base.message 2')
      end

      I18n.with_locale_array([ 'it', 'en' ]) do
        t = I18n.tx('base.sub')
        expect(t).to eql({
                           msg2: "IT base.sub.message 2",
                           html: "<b>IT base.sub.html</b>",
                           unsafe: "<b>IT base.sub.unsafe</b>",
                           subsub: {
                             msg4: "IT base.sub.subsub.message 4"
                           }
                         })
      end
    end

    it 'should set locales for .localize_x' do
      expect(I18n.localize_x(dt1, format: :year)).to eql('EN year: 2020')

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.localize_x(dt1, format: :year)).to eql('IT year: 2020')
      end

      I18n.with_locale_array([ 'en', 'it' ]) do
        expect(I18n.localize_x(dt1, format: :year)).to eql('EN year: 2020')
      end

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.localize_x(dt1, format: :day)).to eql('EN day: 10')
      end
    end

    it 'should set locales for .translate' do
      expect(I18n.translate('msg1')).to eql('EN message 1')

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.translate('msg1')).to eql('IT message 1')
      end

      I18n.with_locale_array([ 'en', 'it' ]) do
        expect(I18n.translate('msg1')).to eql('EN message 1')
      end

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.translate('base.msg2')).to eql('EN base.message 2')
      end
    end
    
    it 'should set locales for .localize' do
      expect(I18n.localize(dt1, format: :year)).to eql('EN year: 2020')

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.localize(dt1, format: :year)).to eql('IT year: 2020')
      end

      I18n.with_locale_array([ 'en', 'it' ]) do
        expect(I18n.localize(dt1, format: :year)).to eql('EN year: 2020')
      end

      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.localize(dt1, format: :day)).to eql('EN day: 10')
      end
    end

    it 'should be overridden by the :locale option' do
      I18n.with_locale_array([ 'it', 'en' ]) do
        expect(I18n.translate_x('msg1', locale: [ 'en' ])).to eql('EN message 1')
        expect(I18n.translate_x('msg1')).to eql('IT message 1')

        expect(I18n.localize_x(dt1, format: :year, locale: [ 'en' ])).to eql('EN year: 2020')
        expect(I18n.localize_x(dt1, format: :year)).to eql('IT year: 2020')

        expect(I18n.translate('msg1', locale: [ 'en' ])).to eql('EN message 1')
        expect(I18n.translate('msg1')).to eql('IT message 1')

        expect(I18n.localize(dt1, format: :year, locale: [ 'en' ])).to eql('EN year: 2020')
        expect(I18n.localize(dt1, format: :year)).to eql('IT year: 2020')
      end
    end
  end
end
