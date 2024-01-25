RSpec.describe ActionView::Helpers::TranslationHelper do
  class TestHelper
    extend ActionView::Helpers::TranslationHelper
    extend I18n::FlHelpers
  end
  
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

  def _html_missing(locale, key, **options)
    o = {}.merge(options)
    o = o.merge(locale: locale) unless locale.nil?

    return TestHelper.send(:_missing_translation, key, options)
  end
  
  let(:th) { TestHelper }
  
  describe '.translate_x' do
    it 'should accept defaults' do
      I18n.locale_array = [ :it, :en ]
      
      expect(th.translate_x('msg1')).to eql('IT message 1')
      expect(th.translate_x('base.msg2')).to eql('EN base.message 2')
      expect(th.translate_x('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(th.translate_x('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should be aliased to :tx' do
      I18n.locale_array = [ :it, :en ]
      
      expect(th.tx('msg1')).to eql('IT message 1')
      expect(th.tx('base.msg2')).to eql('EN base.message 2')
      expect(th.tx('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(th.tx('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should be aliased to :translate' do
      I18n.locale_array = [ :it, :en ]
      
      expect(th.translate('msg1')).to eql('IT message 1')
      expect(th.translate('base.msg2')).to eql('EN base.message 2')
      expect(th.translate('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(th.translate('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should be aliased to :t' do
      I18n.locale_array = [ :it, :en ]
      
      expect(th.t('msg1')).to eql('IT message 1')
      expect(th.t('base.msg2')).to eql('EN base.message 2')
      expect(th.t('base.sub.msg2')).to eql('IT base.sub.message 2')
      expect(th.t('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
    end

    it 'should return nil on a nil key' do
      expect(th.tx(nil)).to be_nil
    end

    it 'should return a message with an invalid locale' do
      I18n.locale_array = [ :xx ]
        
      t = th.tx('msg1')
      expect(t).to be_a(ActiveSupport::SafeBuffer)
      expect(t).to eql(_html_missing(nil, 'msg1'))
    end

    it 'should return a message with an undefined key' do
      I18n.locale_array = [ :en ]
        
      t = th.tx('not.a.key')
      expect(t).to be_a(ActiveSupport::SafeBuffer)
      expect(t).to eql(_html_missing(nil, 'not.a.key'))
    end

    it 'should support the :default option' do
      expect(th.tx('missing', default: 'default value')).to eql('default value')
      expect(th.tx(:missing, default: 'base.msg1'.to_sym)).to eql('EN base.message 1')
    end

    it 'should translate arrays of keys' do
      expect(th.translate_x([ 'msg1', 'base.msg1' ])).to eql([ 'EN message 1', 'EN base.message 1' ])
    end

    it 'should return hashes for non-leaf nodes' do
      t = th.tx('base.sub')
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

      # the translation helper does not accept the :locale option, so to pick up an explicit locale
      # we need to reset it in I18n::config.locale_array

      I18n.locale_array = [ :it ]
      t = th.tx('base.sub')
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
      expect(th.tx('msg3', scope: 'base.sub.subsub')).to eql('EN base.sub.subsub.message 3')
      expect(th.tx('msg3', scope: [ 'base', 'sub', 'subsub' ])).to eql('EN base.sub.subsub.message 3')
      expect(th.tx([ 'msg3', 'msg2' ],
                   scope: [ 'base', 'sub' ])).to eql([ 'EN base.sub.message 3', 'EN base.sub.message 2' ])

      expect(th.tx('msg2', scope: [ :base, 'sub' ])).to eql('EN base.sub.message 2')
      expect(th.tx('msg2', scope: 'base.sub')).to eql('EN base.sub.message 2')
    end

    it 'should accept the :raise option' do
      expect do
        th.tx('missing', raise: true)
      end.to raise_exception(I18n::MissingTranslationData)

      exc = nil
      begin
        th.tx('missing', raise: true)
      rescue I18n::MissingTranslationData => x
        exc = x
      end
      expect(exc).to be_a(I18n::MissingTranslationData)
      expect(exc.message).to eql(_missing(:en, 'missing'))
    end

    context 'with multiple locales' do
      it 'should traverse the locales list' do
        I18n.locale_array = [ :it, :en ]

        expect(th.translate_x('msg1')).to eql('IT message 1')
        expect(th.translate_x('base.msg1')).to eql('IT base.message 1')
        expect(th.translate_x('base.msg2')).to eql('EN base.message 2')
        expect(th.translate_x('base.sub.msg2')).to eql('IT base.sub.message 2')
        expect(th.translate_x('base.sub.msg3')).to eql('EN base.sub.message 3')
        expect(th.translate_x('base.sub.subsub.msg3')).to eql('EN base.sub.subsub.message 3')
      end

      it 'should translate arrays of keys' do
        I18n.locale_array = [ :it, :en ]
      
        expect(th.translate_x([ 'base.msg1', 'base.msg2' ])).to eql([ 'IT base.message 1', 'EN base.message 2' ])
      end

      it 'should not raise on unsupported locales' do
        I18n.locale_array = [ :xx, :it, :en ]
      
        expect(th.translate_x('msg1')).to eql('IT message 1')
        expect(th.translate_x('base.msg1')).to eql('IT base.message 1')

        # Does not raise because it finds an :it translation
        expect(th.tx('msg1', raise: true)).to eql('IT message 1')
      end

      it 'should raise on a single unsupported locale' do
        I18n.locale_array = [ :xx ]
      
        expect do
          th.translate_x('msg1', raise: true)
        end.to raise_exception(I18n::InvalidLocale)
      end

      it 'should return a message with an array of unsupported locales' do
        I18n.locale_array = [ :xx, :yy ]
      
        t = th.tx('msg1')
        expect(t).to be_a(String)
        expect(t).to eql(_html_missing(nil, 'msg1'))
      
        expect do
          th.tx('msg1', raise: true)
        end.to raise_exception(I18n::InvalidLocale)

        exc = nil
        begin
          th.tx('msg1', raise: true)
        rescue I18n::InvalidLocale => x
          exc = x
        end
        expect(exc.message).to start_with(':xx ')
      end
    end

    context 'with safe keys' do
      it 'should detect a _html name' do
        t = th.translate_x('base.msg2_html')
        expect(t).to be_a(ActiveSupport::SafeBuffer)
        expect(t).to eql("<b>EN base.message 2 HTML</b>")
      end

      it 'should detect a .html name' do
        t = th.translate_x('base.sub.html')
        expect(t).to be_a(ActiveSupport::SafeBuffer)
        expect(t).to eql("<b>EN base.sub.html</b>")
      end

      it 'should process an array of keys' do
        t = th.translate_x([ :'base.msg2_html', 'base.sub.html' ])
        expect(t).to be_a(Array)
        expect(t[0]).to be_a(ActiveSupport::SafeBuffer)
        expect(t[0]).to eql("<b>EN base.message 2 HTML</b>")
        expect(t[1]).to be_a(ActiveSupport::SafeBuffer)
        expect(t[1]).to eql("<b>EN base.sub.html</b>")
      end
    end

    context 'with the :default option' do
      it 'should accept a plain string' do
        expect(th.tx('not.a.key', default: 'default value')).to eql('default value')
        expect(th.tx([ 'not.a.key', 'no2' ], default: 'default value')).to eql([ 'default value', 'default value' ])
        expect(th.tx([ 'not.a.key', 'msg1' ], default: 'default value')).to eql([ 'default value', 'EN message 1' ])
      end

      it 'should accept a symbol for an alternate key' do
        expect(th.tx('not.a.key', default: 'base.msg1'.to_sym)).to eql('EN base.message 1')
        expect(th.tx([ 'not.a.key', 'no2' ],
                     default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN base.message 1' ])
        expect(th.tx([ 'not.a.key', 'msg1' ],
                     default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN message 1' ])
      end

      it 'should accept a scalar default for a single key' do
        expect(th.tx('not.a.key',
                     default: 'base.msg1'.to_sym )).to eql('EN base.message 1')
        expect(th.tx('not.a.key', default: 'backstop')).to eql('backstop')
      end

      it 'should accept an array of defaults for a single key' do
        expect(th.tx('not.a.key',
                     default: [ 'base.msg1'.to_sym ])).to eql('EN base.message 1')
        expect(th.tx('not.a.key',
                     default: [ 'base.msg10'.to_sym, 'backstop' ])).to eql('backstop')
        expect(th.tx('not.a.key',
                     locale: [ :it, :en ],
                     default: [ 'base.msg1'.to_sym, 'backstop' ])).to eql('IT base.message 1')
        expect(th.tx('not.a.key',
                     locale: [ :it, :en ],
                     default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql('EN base.message 2')
      end

      it 'should give priority to alternate keys over strings' do
        I18n.locale_array = [ :it, :en ]
        
        expect(th.tx('not.a.key',
                     default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql('EN base.message 2')
      end

      context 'with multiple keys' do
        it 'should accept a common scalar default' do
          expect(th.tx([ 'not.a.key', 'no2' ],
                       default: 'base.msg1'.to_sym)).to eql([ 'EN base.message 1', 'EN base.message 1' ])
          expect(th.tx([ 'not.a.key', 'msg1' ],
                       default: 'backstop')).to eql([ 'backstop', 'EN message 1' ])
        end

        it 'uses common defaults if array lengths are not the same' do
          expect(th.tx([ 'not.a.key', 'no2', 'no3' ],
                       default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                              'EN base.message 2',
                                                                              'EN base.message 2' ])
          I18n.locale_array = [ :it, :en ]
          expect(th.tx([ 'not.a.key', 'no2', 'no3' ],
                       locale: [ :it, :en ],
                       default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                              'EN base.message 2',
                                                                              'EN base.message 2' ])
          I18n.locale_array = [ :it ]
          expect(th.tx([ 'not.a.key', 'no2', 'no3' ],
                       default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'backstop',
                                                                              'backstop',
                                                                              'backstop' ])
        end

        it 'uses custom defaults if same array length and all elements are arrays' do
          expect(th.tx([ 'not.a.key', 'no2' ],
                       default: [
                         [ 'base.msg2'.to_sym, 'backstop' ],
                         [ 'base.msg1'.to_sym, 'default' ]
                       ])).to eql([ 'EN base.message 2',
                                    'EN base.message 1' ])

          I18n.locale_array = [ :it, :en ]
          expect(th.tx([ 'not.a.key', 'no2', 'no3' ],
                       default: [
                         [ 'base.msg2'.to_sym, 'backstop' ],
                         [ 'base.msg1'.to_sym, 'default' ],
                         [ 'no3 default' ]
                       ])).to eql([ 'EN base.message 2',
                                    'IT base.message 1',
                                    'no3 default' ])

          I18n.locale_array = [ :it, :en ]
          expect(th.tx([ 'not.a.key', 'no2', 'base.msg12', 'base.msg1' ],
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
          expect(th.tx([ 'not.a.key', 'no2' ],
                       default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                              'EN base.message 2' ])

          I18n.locale_array = [ :it, :en ]
          expect(th.tx([ 'not.a.key', 'no2' ],
                       default: [ 'base.msg2'.to_sym, 'backstop' ])).to eql([ 'EN base.message 2',
                                                                              'EN base.message 2' ])

          I18n.locale_array = [ :it, :en ]
          expect(th.tx([ 'not.a.key', 'no2' ],
                       default: [ 'base.msg20'.to_sym, 'backstop' ])).to eql([ 'backstop',
                                                                               'backstop' ])
        end
      end
    end

    context 'on a missing translation' do
      it 'should return an error string by default' do
        key = 'not.a.key'
        expect(th.tx(key)).to eql(_html_missing(nil, key))

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect(th.tx(key)).to eql([ 'EN message 1',
                                      _html_missing(nil, key[1]),
                                      'EN base.message 1'
                                    ])
      end

      it 'should raise an exception if configured' do
        key = 'not.a.key'
        expect do
          th.tx(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          th.tx(key, raise: true)
        rescue Exception => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to eql(_missing(:en, key))

        key = [ 'msg1', 'not.a.key', 'base.msg1' ]
        expect do
          th.tx(key, raise: true)
        end.to raise_error(I18n::MissingTranslationData)

        exc = nil
        begin
          th.tx(key, raise: true)
        rescue Exception => x
          exc = x
        end
        expect(exc).to be_a(I18n::MissingTranslationData)
        expect(exc.message).to eql(_missing(:en, key[1]))
      end
    end
  end
end
