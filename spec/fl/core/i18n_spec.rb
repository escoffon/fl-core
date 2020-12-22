RSpec.describe I18n do
  before(:example) do
    I18n.locale_array = [ :en ]
  end
  
  let(:dt1) { Time.new(2020, 2, 10, 10, 20, 30) }
  let(:dt2) { Time.new(2022, 4, 20, 12, 22, 32) }

  def _sym(l)
    l.map { |e| e.to_sym }
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
      expect(I18n.translate_x('msg1')).to eql('EN message 1')
      expect(I18n.translate_x('base.msg1')).to eql('EN base.message 1')
      expect(I18n.translate_x('base.sub.msg2')).to eql('EN base.sub.message 2')
      expect(I18n.translate_x('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should be aliased to :tx' do
      expect(I18n.tx('msg1')).to eql('EN message 1')
      expect(I18n.tx('base.msg1')).to eql('EN base.message 1')
      expect(I18n.tx('base.sub.msg2')).to eql('EN base.sub.message 2')
      expect(I18n.tx('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should raise an exception on a nil key' do
      expect do
        I18n.tx(nil, default: [ 'base.msg1'.to_sym, [ 'foo' ] ])
      end.to raise_error(ArgumentError)
    end

    it 'should translate arrays of keys' do
      expect(I18n.translate_x([ 'msg1', 'base.msg1' ])).to eql([ 'EN message 1', 'EN base.message 1' ])
    end

    it 'should return hashes for non-leaf nodes' do
      t = I18n.tx('base.sub')
      expect(t).to eql({
                         msg2: "EN base.sub.message 2",
                         msg3: "EN base.sub.message 3",
                         subsub: {
                           msg3: "EN base.sub.subsub.message 3",
                           msg4: "EN base.sub.subsub.message 4"
                         }
                       })

      t = I18n.tx('base.sub', locale: 'it')
      expect(t).to eql({
                         msg2: "IT base.sub.message 2",
                         subsub: {
                           msg4: "IT base.sub.subsub.message 4"
                         }
                       })
    end
    
    it 'should accept a :locale option' do
      expect(I18n.translate_x('msg1', locale: [ :it, 'en' ])).to eql('IT message 1')
      expect(I18n.translate_x('base.msg2', locale: [ :it, 'en' ])).to eql('EN base.message 2')

      expect(I18n.translate_x([ 'msg1', 'base.msg2' ],
                              locale: [ :it, 'en' ])).to eql([ 'IT message 1', 'EN base.message 2' ])
    end

    it 'should accept a :scope option' do
      expect(I18n.tx('msg3', scope: 'base.sub.subsub')).to eql('EN base.sub.subsub.message 3')
      expect(I18n.tx('msg3', scope: [ 'base', 'sub', 'subsub' ])).to eql('EN base.sub.subsub.message 3')
      expect(I18n.tx([ 'msg3', 'msg2' ],
                     scope: [ 'base', 'sub' ])).to eql([ 'EN base.sub.message 3', 'EN base.sub.message 2' ])
    end

    context 'with the :default option' do
      let(:h1) { { h1: 'h1' } }
      let(:h2) { { h2: 'h2' } }

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

      it 'should accept a hash' do
        expect(I18n.tx('not.a.key', default: h1)).to eql(h1)
        expect(I18n.tx([ 'not.a.key', 'no2' ], default: h1)).to eql([ h1, h1 ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], default: h1)).to eql([ h1, 'EN message 1' ])
      end
      
      it 'should raise an exception on a scalar key and array :default with arrays' do
        expect do
          I18n.tx('not.a.key', default: [ 'base.msg1'.to_sym, [ 'foo' ] ])
        end.to raise_error(ArgumentError)

        expect do
          I18n.tx('not.a.key', default: [ [ 'foo' ], [ 'bar' ] ])
        end.to raise_error(ArgumentError)
      end

      it 'should raise an exception on a mixed array :default' do
        expect do
          I18n.tx([ 'not.a.key', 'foo' ], default: [ 'base.msg1'.to_sym, [ 'foo' ] ])
        end.to raise_error(ArgumentError)

        expect do
          I18n.tx('msg1', default: [ 'base.msg1'.to_sym, [ 'foo' ] ])
        end.to raise_error(ArgumentError)
      end

      it 'should process a single array in :default' do
        expect(I18n.tx('not.a.key', default: [ 'base.msg1'.to_sym, 'backstop' ])).to eql('EN base.message 1')
        expect(I18n.tx('not.a.key', default: [ 'bs1', 'base.msg1'.to_sym, 'bs2' ])).to eql('EN base.message 1')
        expect(I18n.tx('not.a.key', locale: [ 'it' ],
                       default: [ 'bs1', 'base.msg2'.to_sym, 'bs2' ])).to eql('bs1')

        expect(I18n.tx([ 'not.a.key', 'no2' ],
                       default: [ 'base.msg1'.to_sym, 'backstop' ])).to eql([ 'EN base.message 1',
                                                                              'EN base.message 1' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], locale: [ 'it' ],
                       default: [ 'backstop', 'base.msg1'.to_sym ])).to eql([ 'IT base.message 1', 'IT message 1' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], locale: [ 'it' ],
                       default: [ 'backstop', 'base.msg2'.to_sym ])).to eql([ 'backstop', 'IT message 1' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], locale: [ 'it' ],
                       default: [ h1, 'base.msg2'.to_sym ])).to eql([ h1, 'IT message 1' ])
      end

      it 'should process an array of arrays in :default' do
        expect(I18n.tx([ 'not.a.key', 'no2' ],
                       default: [ [ 'base.msg1'.to_sym, 'backstop1' ],
                                  [ 'base.msg2'.to_sym, 'backstop2' ] ])).to eql([ 'EN base.message 1',
                                                                                   'EN base.message 2' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ],
                       default: [ [ 'backstop1', 'base.msg2'.to_sym ],
                                  [ 'backstop2', 'base.msg2'.to_sym ] ])).to eql([ 'EN base.message 2', 'EN message 1' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], locale: [ 'it' ],
                       default: [ [ 'backstop1', 'base.msg2'.to_sym ],
                                  [ 'backstop2', 'base.msg2'.to_sym ] ])).to eql([ 'backstop1', 'IT message 1' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], locale: [ 'it' ],
                       default: [ [ h1, 'base.msg2'.to_sym ],
                                  [ h2, 'base.msg2'.to_sym ] ])).to eql([ h1, 'IT message 1' ])

        expect(I18n.tx([ 'not.a.key', 'no2' ], locale: [ 'it', 'en' ],
                       default: [ [ 'base.msg1'.to_sym, 'backstop1' ],
                                  [ 'base.msg2'.to_sym, 'backstop2' ] ])).to eql([ 'IT base.message 1',
                                                                                   'EN base.message 2' ])
        expect(I18n.tx([ 'not.a.key', 'no2' ], locale: [ 'it', 'en' ],
                       default: [ [ 'base.msg1'.to_sym, h1 ],
                                  [ 'base.msg2'.to_sym, h2 ] ])).to eql([ 'IT base.message 1',
                                                                          'EN base.message 2' ])
        expect(I18n.tx([ 'not.a.key', 'msg1' ], locale: [ 'it', 'en' ],
                       default: [ [ 'backstop1', 'base.msg1'.to_sym ],
                                  [ 'backstop2', 'base.msg2'.to_sym ] ])).to eql([ 'IT base.message 1',
                                                                                   'IT message 1' ])
        expect(I18n.tx([ 'not.a.key', 'no2' ], locale: [ 'it' ],
                       default: [ [ 'base.msg1'.to_sym, 'backstop1' ],
                                  [ 'base.msg2'.to_sym, 'backstop2' ] ])).to eql([ 'IT base.message 1',
                                                                                   'backstop2' ])
        expect(I18n.tx([ 'not.a.key', 'no2' ], locale: [ 'it' ],
                       default: [ [ 'base.msg1'.to_sym, h1 ],
                                  [ 'base.msg2'.to_sym, h2 ] ])).to eql([ 'IT base.message 1',
                                                                          h2 ])
      end
    end
    
    context 'on a missing translation' do
      it 'should return an error string by default' do
        key = 'not.a.key'
        expect(I18n.tx(key)).to start_with("translation missing: [en].#{key}")

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect(I18n.tx(key)).to eql([ 'EN message 1', "translation missing: [en].#{key[1]}", 'EN base.message 1' ])
      end

      it 'should raise an exception if configured' do
        key = 'not.a.key'
        expect do
          I18n.tx(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          I18n.tx(key, raise: true)
        rescue => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to start_with("translation missing: [en].#{key}")

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect do
          I18n.tx(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          I18n.tx(key, raise: true)
        rescue => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to start_with("translation missing: [en].#{key[1]}")
      end

      it 'should throw a symbol if configured' do
        key = 'not.a.key'
        expect do
          I18n.tx(key, throw: true)
        end.to throw_symbol(:exception)

        expect do
          I18n.tx(key, throw: :foo)
        end.to throw_symbol(:exception)

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect do
          I18n.tx(key, throw: true)
        end.to throw_symbol(:exception)
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
    
    it 'should raise an exception on a nil key' do
      expect do
        I18n.translate(nil, default: [ 'base.msg1'.to_sym, [ 'foo' ] ])
      end.to raise_error(ArgumentError)
    end

    context 'with the :default option' do
      it 'should implement the translate_x functionality' do
        expect(I18n.t('not.a.key', default: 'default value')).to eql('default value')
        expect(I18n.t([ 'not.a.key', 'msg1' ], default: 'default value')).to eql([ 'default value', 'EN message 1' ])

        expect(I18n.t([ 'not.a.key', 'no2' ],
                      default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN base.message 1' ])

        expect(I18n.t('not.a.key', default: [ 'bs1', 'base.msg1'.to_sym, 'bs2' ])).to eql('EN base.message 1')
        expect(I18n.t('not.a.key', locale: [ 'it' ],
                      default: [ 'bs1', 'base.msg2'.to_sym, 'bs2' ])).to eql('bs1')

        expect(I18n.t([ 'not.a.key', 'no2' ],
                      default: [ [ 'base.msg1'.to_sym, 'backstop1' ],
                                 [ 'base.msg2'.to_sym, 'backstop2' ] ])).to eql([ 'EN base.message 1',
                                                                                  'EN base.message 2' ])
        expect(I18n.t([ 'not.a.key', 'msg1' ], locale: [ 'it' ],
                      default: [ [ 'backstop1', 'base.msg2'.to_sym ],
                                 [ 'backstop2', 'base.msg2'.to_sym ] ])).to eql([ 'backstop1', 'IT message 1' ])
      end
    end
    
    context 'on a missing translation' do
      it 'should implement the translate_x functionality' do
        key = 'not.a.key'
        expect(I18n.t(key)).to start_with("translation missing: [en].#{key}")

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect(I18n.t(key)).to eql([ 'EN message 1', "translation missing: [en].#{key[1]}", 'EN base.message 1' ])

        expect do
          I18n.t(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        expect do
          I18n.t(key, throw: true)
        end.to throw_symbol(:exception)
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
      rescue => xx
        x = xx
      end
      expect(x.message).to start_with('translation missing: [en].time.formats.unknown')
      expect(x.key).to eql('time.formats.unknown'.to_sym)

      expect do
        I18n.localize_x(dt1, format: :unknown, locale: [ 'it', 'en' ])
      end.to raise_exception(I18n::MissingTranslationData)

      x = nil
      begin
        I18n.localize_x(dt1, format: :unknown, locale: [ 'it', 'en' ])
      rescue => xx
        x = xx
      end
      expect(x.message).to start_with('translation missing: [it,en].time.formats.unknown')
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
      rescue => xx
        x = xx
      end
      expect(x.message).to start_with('translation missing: [en].time.formats.unknown')
      expect(x.key).to eql('time.formats.unknown'.to_sym)

      expect do
        I18n.localize(dt1, format: :unknown, locale: [ 'it', 'en' ])
      end.to raise_exception(I18n::MissingTranslationData)

      x = nil
      begin
        I18n.localize(dt1, format: :unknown, locale: [ 'it', 'en' ])
      rescue => xx
        x = xx
      end
      expect(x.message).to start_with('translation missing: [it,en].time.formats.unknown')
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
