RSpec.describe Fl::Core::Icalendar do
  # The local timezone for all tests is America/Los_Angeles

  before(:example) do
    @cur_tz = Time.zone
    Time.zone = 'America/Los_Angeles'
  end

  after(:example) do
    Time.zone = @cur_tz
  end

  def today(tz = nil)
    tzz = if tz.is_a?(String)
            ActiveSupport::TimeZone.new(tz)
          elsif tz.nil?
            Time.zone
          else
            tz
          end
    t = tzz.now
    sprintf('%04d%02d%02d', t.year, t.month, t.day)
  end

  context '.datetime_to_time' do
    # Time.local does not seem to use the current timezone; instead, it seems to get the local timezone info
    # based on the host's timezone settings, which may be different from the test case's since the test case
    # sets the Time timezone to America/Los_Angeles.
    # So there is a bit of an inconsistencty between the time returned by Time.local and the ones returned
    # by the ICalendar stuff.

    it 'should convert a local time string' do
      cur_tz = Time.zone

      t = Time.utc(2014, 1, 20, 10, 20, 30)
      expect(Fl::Core::Icalendar.datetime_to_time('20140120T102030').to_i).to eql(t.to_i - cur_tz.utc_offset)
    end

    it 'should convert a UTC time string' do
      t = Time.utc(2014, 1, 20, 10, 20, 30)
      expect(Fl::Core::Icalendar.datetime_to_time('20140120T102030Z').to_i).to eql(t.to_i)
    end

    it 'should convert a time string with time zone qualifier' do
      Time.zone = 'Europe/Rome'
      t = Time.zone.parse('2014-01-20 10:20:30')
      expect(Fl::Core::Icalendar.datetime_to_time('TZID=Europe/Rome:20140120T102030').to_i).to eql(t.to_i)
    end
    
    it 'should convert a Time object' do
      t = Time.now
      expect(Fl::Core::Icalendar.datetime_to_time(t).to_i).to eql(t.to_i)

      t = Time.utc(2014, 1, 20, 10, 20, 30)
      expect(Fl::Core::Icalendar.datetime_to_time(t).to_i).to eql(t.to_i)

      Time.zone = 'Europe/Rome'
      t = Time.zone.parse('2014-01-20 10:20:30')
      assert_equal t.to_i, Fl::Core::Icalendar.datetime_to_time(t).to_i
    end

    it 'should convert an Icalendar::Datetime object' do
      cur_tz = Time.zone

      t = Time.utc(2014, 1, 20, 10, 20, 30)
      dt = Fl::Core::Icalendar::Datetime.new('20140120T102030')
      expect(Fl::Core::Icalendar.datetime_to_time(dt).to_i).to eql(t.to_i - cur_tz.utc_offset)

      dt = Fl::Core::Icalendar::Datetime.new('20140120T102030Z')
      expect(Fl::Core::Icalendar.datetime_to_time(dt).to_i).to eql(t.to_i)

      Time.zone = 'Europe/Rome'
      t = Time.zone.parse('2014-01-20 10:20:30')
      dt = Fl::Core::Icalendar::Datetime.new("TZID=Europe/Rome:20140120T102030")
      assert_equal t.to_i, Fl::Core::Icalendar.datetime_to_time(t).to_i
    end
  end

  context '.split_datetime' do
    it 'should return a nil timezone if timezone qualifier is missing' do
      dt, tz = Fl::Core::Icalendar.split_datetime('20140112T102030')
      expect(tz).to be_nil
      expect(dt).to eql('20140112T102030')
    end

    it 'should return \'UTC\' for a Z timezone qualifier' do
      dt, tz = Fl::Core::Icalendar.split_datetime('20140112T102030Z')
      expect(tz).to eql('UTC')
      expect(dt).to eql('20140112T102030')
    end
    
    it 'should parse a \'TZID\' timezone qualifier' do
      dt, tz = Fl::Core::Icalendar.split_datetime('TZID=America/Los_Angeles:20140112T102030')
      expect(tz).to eql('America/Los_Angeles')
      expect(dt).to eql('20140112T102030')
    end
  end

  context '.format_datetime' do
    it 'should generate a datetime representation' do
      tz_base = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt = tz_base.parse('20140110T102030')
      expect(Fl::Core::Icalendar.format_datetime(dt)).to eql('20140110T102030')
    end
    
    it 'should track a Datetime time zone' do
      tz_base = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt = tz_base.parse('20140110T102030')

      tz_alt = ActiveSupport::TimeZone.new('America/New_York')
      dt_alt = dt.in_time_zone(tz_alt)
      expect(Fl::Core::Icalendar.format_datetime(dt_alt)).to eql('20140110T132030')

      tz_base = ActiveSupport::TimeZone.new('Europe/Rome')
      dt = tz_base.parse('20140110T062030')
      expect(Fl::Core::Icalendar.format_datetime(dt)).to eql('20140110T062030')

      tz_alt = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt_alt = dt.in_time_zone(tz_alt)
      expect(Fl::Core::Icalendar.format_datetime(dt_alt)).to eql('20140109T212030')
    end
  end

  context '.format_date' do
    it 'should generate a date representation' do
      tz_base = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt = tz_base.parse('20140110T102030')
      expect(Fl::Core::Icalendar.format_date(dt)).to eql('20140110')
    end
    
    it 'should track a Datetime time zone' do
      tz_base = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt = tz_base.parse('20140110T102030')

      tz_alt = ActiveSupport::TimeZone.new('America/New_York')
      dt_alt = dt.in_time_zone(tz_alt)
      expect(Fl::Core::Icalendar.format_date(dt_alt)).to eql('20140110')

      tz_base = ActiveSupport::TimeZone.new('Europe/Rome')
      dt = tz_base.parse('20140110T062030')
      expect(Fl::Core::Icalendar.format_date(dt)).to eql('20140110')

      tz_alt = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt_alt = dt.in_time_zone(tz_alt)
      expect(Fl::Core::Icalendar.format_date(dt_alt)).to eql('20140109')
    end
  end

  context '.format_time' do
    it 'should generate a time representation' do
      tz_base = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt = tz_base.parse('20140110T102030')
      expect(Fl::Core::Icalendar.format_time(dt)).to eql('102030')
    end
    
    it 'should track a Datetime time zone' do
      tz_base = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt = tz_base.parse('20140110T102030')

      tz_alt = ActiveSupport::TimeZone.new('America/New_York')
      dt_alt = dt.in_time_zone(tz_alt)
      expect(Fl::Core::Icalendar.format_time(dt_alt)).to eql('132030')

      tz_base = ActiveSupport::TimeZone.new('Europe/Rome')
      dt = tz_base.parse('20140110T062030')
      expect(Fl::Core::Icalendar.format_time(dt)).to eql('062030')

      tz_alt = ActiveSupport::TimeZone.new('America/Los_Angeles')
      dt_alt = dt.in_time_zone(tz_alt)
      expect(Fl::Core::Icalendar.format_time(dt_alt)).to eql('212030')
    end
  end

  context '.parse' do
    it 'should parse a datetime with no timezone qualifier' do
      dt = Fl::Core::Icalendar.parse('20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      expect(dt.to_i).to eql(dt_local.to_i)
      expect(Fl::Core::Icalendar.format_datetime(dt_local)).to eql('20140110T102030')
    end
    
    it 'should parse a datetime with timezone qualifier and adjust for it' do
      dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      expect(dt.to_i).to eql(dt_local.to_i)
      expect(Fl::Core::Icalendar.format_datetime(dt_local)).to eql('20140110T102030')

      dt = Fl::Core::Icalendar.parse('TZID=America/New_York:20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      expect(dt.to_i).to eql(dt_local.to_i)
      expect(Fl::Core::Icalendar.format_datetime(dt_local)).to eql('20140110T072030')

      dt = Fl::Core::Icalendar.parse('20140110T102030Z')
      dt_local = dt.in_time_zone(Time.zone)
      expect(dt.to_i).to eql(dt_local.to_i)
      expect(Fl::Core::Icalendar.format_datetime(dt_local)).to eql('20140110T022030')

      dt = Fl::Core::Icalendar.parse('TZID=Europe/Rome:20140110T102030')
      dt_local = dt.in_time_zone(Time.zone)
      expect(dt.to_i).to eql(dt_local.to_i)
      expect(Fl::Core::Icalendar.format_datetime(dt_local)).to eql('20140110T012030')
    end

    it 'should return nil on unknown timezones' do
      expect(Fl::Core::Icalendar.parse('TZID=America/Menlo_Park:20140110T102030')).to be_nil
    end
  end

  context '.in_time_zone' do
    it 'should convert between time zones' do
      dt = Fl::Core::Icalendar.in_time_zone('20140110T102030Z', 'America/Los_Angeles')
      expect(dt).to eql('TZID=America/Los_Angeles:20140110T022030')
      d = Fl::Core::Icalendar.parse('20140110T102030Z')
      dt = Fl::Core::Icalendar.in_time_zone(d, 'America/Los_Angeles')
      expect(dt).to eql('TZID=America/Los_Angeles:20140110T022030')

      dt = Fl::Core::Icalendar.in_time_zone('TZID=America/New_York:20140110T102030', 'America/Los_Angeles')
      expect(dt).to eql('TZID=America/Los_Angeles:20140110T072030')

      d = Fl::Core::Icalendar.parse('TZID=America/New_York:20140110T102030')
      dt = Fl::Core::Icalendar.in_time_zone(d, 'America/Los_Angeles')
      expect(dt).to eql('TZID=America/Los_Angeles:20140110T072030')

      s_5545 = 'TZID=America/New_York:20160210T102040'
      dt = Fl::Core::Icalendar::Datetime.new(s_5545)
      ts_ny = dt.to_i
      ts_ca = dt.in_timezone('America/Los_Angeles').to_i
      expect(ts_ca - ts_ny).to eql(180 * 60)
      ts_co = dt.in_timezone(ActiveSupport::TimeZone.new('America/Denver')).to_i
      expect(ts_co - ts_ny).to eql(120 * 60)
    end
  end

  context '.valid_timezone' do
    it 'should validate correctly' do
      expect(Fl::Core::Icalendar::Datetime.valid_timezone?('UTC')).to eql(true)
      expect(Fl::Core::Icalendar::Datetime.valid_timezone?('America/Los_Angeles')).to eql(true)
      expect(Fl::Core::Icalendar::Datetime.valid_timezone?('America/Menlo_Park')).to eql(false)
    end
  end

  context '.date_type' do
    it 'should return NONE for invalid formats' do
      expect(Fl::Core::Icalendar.date_type('foo')).to eql('NONE')
      expect(Fl::Core::Icalendar.date_type('fooZ')).to eql('NONE')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Los_Angeles:foo')).to eql('NONE')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Los_Angeles:1234T56')).to eql('NONE')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Menlo_Park:20140110')).to eql('NONE')
    end

    it 'should return DATE-TIME if both date and time components are present' do
      expect(Fl::Core::Icalendar.date_type('20140110T102030')).to eql('DATE-TIME')
      expect(Fl::Core::Icalendar.date_type('20140110T1020')).to eql('DATE-TIME')
      expect(Fl::Core::Icalendar.date_type('20140110T102030Z')).to eql('DATE-TIME')
      expect(Fl::Core::Icalendar.date_type('20140110T1020Z')).to eql('DATE-TIME')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Los_Angeles:20140110T102030')).to eql('DATE-TIME')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Los_Angeles:20140110T1020')).to eql('DATE-TIME')
    end
    
    it 'should return DATE if only date component is present' do
      expect(Fl::Core::Icalendar.date_type('20140110')).to eql('DATE')
      expect(Fl::Core::Icalendar.date_type('20140110Z')).to eql('DATE')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Los_Angeles:20140110')).to eql('DATE')
    end

    it 'should return TIME if only time component is present' do
      expect(Fl::Core::Icalendar.date_type('102030')).to eql('TIME')
      expect(Fl::Core::Icalendar.date_type('1020')).to eql('TIME')
      expect(Fl::Core::Icalendar.date_type('102030Z')).to eql('TIME')
      expect(Fl::Core::Icalendar.date_type('1020Z')).to eql('TIME')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Los_Angeles:102030')).to eql('TIME')
      expect(Fl::Core::Icalendar.date_type('TZID=America/Los_Angeles:1020')).to eql('TIME')
    end
  end
  
  describe Fl::Core::Icalendar::Property do
    describe Fl::Core::Icalendar::Property::Base do
      context '.parse' do
        it 'should parse a simple property string' do
          x = {
            :name => 'SIMPLE',
            :params => {},
            :value => 'value for simple'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('SIMPLE:value for simple')).to eql(x)
          expect(Fl::Core::Icalendar::Property::Base.parse('simple:value for simple')).to eql(x)
        end

        it 'should parse a property string with parameters' do
          x = {
            :name => 'NAME',
            :params => {
              :PAR1 => 'value for PAR1'
            },
            :value => 'value for name'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('NAME;PAR1=value for PAR1:value for name')).to eql(x)
          expect(Fl::Core::Icalendar::Property::Base.parse('name;PAR1="value for PAR1":value for name')).to eql(x)

          x = {
            :name => 'NAME',
            :params => {
              :PAR1 => 'value for par1'
            },
            :value => 'value for name'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('NAME;par1=value for par1:value for name')).to eql(x)
          expect(Fl::Core::Icalendar::Property::Base.parse('name;par1="value for par1":value for name')).to eql(x)

          x = {
            :name => 'NAME',
            :params => {
              :PAR1 => 'value for par1',
              :PAR2 => 'value for par2'
            },
            :value => 'value for name'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('NAME;par2=value for par2;par1=value for par1:value for name')).to eql(x)
          expect(Fl::Core::Icalendar::Property::Base.parse('name;par1="value for par1";par2="value for par2":value for name')).to eql(x)
        end

        it 'should parse values containing : or ;' do
          x = {
            :name => 'NAME',
            :params => {
              :PAR1 => 'value : for par1',
              :PAR2 => 'value for ; par2'
            },
            :value => 'value for name'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('name;par1="value : for par1";par2="value for ; par2":value for name')).to eql(x)
        end

        it 'should extract the :type from a VALUE parameter' do
          x = {
            :name => 'NAME',
            :params => {
              :VALUE => 'DATE-TIME',
              :PAR2 => 'value for ; par2'
            },
            :type => 'DATE-TIME',
            :value => 'value for name'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('name;VALUE=DATE-TIME;par2="value for ; par2":value for name')).to eql(x)
          expect(Fl::Core::Icalendar::Property::Base.parse('name;value=date-time;par2="value for ; par2":value for name')).to eql(x)
        end

        it 'should parse a simple property whose value contains ;' do
          x = {
            :name => 'GEO',
            :params => {},
            :value => '37.386013;-122.082932'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('GEO:37.386013;-122.082932')).to eql(x)
        end

        it 'should properly handle : in a parameter\'s value' do
          x = {
            :name => 'ATTACH',
            :params => {
              :FMTTYPE => 'application/postscript'
            },
            :value => 'ftp://example.com/pub/reports/r-960812.ps'
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('ATTACH;FMTTYPE=application/postscript:ftp://example.com/pub/reports/r-960812.ps')).to eql(x)
        end

        it 'should properly handle escape sequences' do
          x = {
            :name => 'PNAME',
            :params => {
              :ONE => 'one:two'
            },
            :value => "A, B\nC: D; \\E"
          }
          expect(Fl::Core::Icalendar::Property::Base.parse('PNAME;ONE="one:two":A\, B\nC\: D\; \\\\E')).to eql(x)
        end
      end
      
      context '.new' do
        it 'should create a simple property' do
          x = {
            :name => 'SIMPLE',
            :params => {},
            :value => 'value for simple'
          }
          s = 'SIMPLE:value for simple'
          p1 = Fl::Core::Icalendar::Property::Base.new(s)
          p2 = Fl::Core::Icalendar::Property::Base.new(x)
          expect(p1.to_s).to eql(s)
          expect(p2.to_s).to eql(s)
        end

        it 'should create a property with multiple parameters' do
          x = {
            :name => 'NAME',
            :params => {
              :PAR1 => 'value for PAR1'
            },
            :value => 'value for name'
          }
          s = 'NAME;PAR1=value for PAR1:value for name'
          p1 = Fl::Core::Icalendar::Property::Base.new(s)
          p2 = Fl::Core::Icalendar::Property::Base.new(x)
          expect(p1.to_s).to eql(s)
          expect(p2.to_s).to eql(s)

          x = {
            :name => 'NAME',
            :params => {
              :PAR1 => 'value for par1'
            },
            :value => 'value for name'
          }
          s = 'NAME;PAR1=value for par1:value for name'
          p1 = Fl::Core::Icalendar::Property::Base.new(s)
          p2 = Fl::Core::Icalendar::Property::Base.new(x)
          expect(p1.to_s).to eql(s)
          expect(p2.to_s).to eql(s)

          x = {
            :name => 'NAME',
            :params => {
              :PAR1 => 'value for par1',
              :PAR2 => 'value for par2'
            },
            :value => 'value for name'
          }
          s = 'NAME;PAR1=value for par1;PAR2=value for par2:value for name'
          p1 = Fl::Core::Icalendar::Property::Base.new(s)
          p2 = Fl::Core::Icalendar::Property::Base.new(x)
          expect(p1.to_s).to eql(s)
          expect(p2.to_s).to eql(s)
        end

        it 'should create a property with : and ; in the parameter values' do
          x = {
            :name => 'name',
            :params => {
              :par1 => 'value : for par1',
              :PAR2 => 'value for ; par2'
            },
            :value => 'value for name'
          }
          s = 'NAME;PAR1="value : for par1";PAR2="value for ; par2":value for name'
          p1 = Fl::Core::Icalendar::Property::Base.new(s)
          p2 = Fl::Core::Icalendar::Property::Base.new(x)
          expect(p1.to_s).to eql(s)
          expect(p2.to_s).to eql(s)
        end

        it 'should detect the :VALUE parameter and set the :type property' do
          x = {
            :name => 'name',
            :params => {
              :value => 'DATE',
              :PAR2 => 'value for ; par2'
            },
            :value => 'value for name'
          }
          s = 'NAME;VALUE=DATE;PAR2="value for ; par2":value for name'
          p1 = Fl::Core::Icalendar::Property::Base.new(s)
          p2 = Fl::Core::Icalendar::Property::Base.new(x)
          expect(p1.to_s).to eql(s)
          expect(p2.to_s).to eql(s)
          expect(p1.type).to eql('DATE')
          expect(p2.type).to eql('DATE')
        end
      end

      context 'property accessors' do
        context '#name' do
          it 'should set the name' do
            p = Fl::Core::Icalendar::Property::Base.new()
            p.name = 'name'
            expect(p.to_s).to eql('NAME:')
          end

          it 'should get the name' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name' })
            expect(p.name).to eql('NAME')
          end
        end

        context '#value' do
          it 'should set the value' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name' })
            p.value = 'value value here'
            expect(p.to_s).to eql('NAME:value value here')
          end

          it 'should get the value' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value' })
            expect(p.value).to eql('value value')
          end
        end

        context '#set_parameter' do
          it 'should set a parameter' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value' })
            p.set_parameter(:par1, 'value : for par1')
            expect(p.to_s).to eql('NAME;PAR1="value : for par1":value value')
          end

          it 'should override a parameter' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value', params: { PAR1: 'p1' } })
            expect(p.to_s).to eql('NAME;PAR1=p1:value value')
            
            p.set_parameter(:par1, 'value : for par1')
            expect(p.to_s).to eql('NAME;PAR1="value : for par1":value value')
          end

          it 'should detect the :VALUE parameter and set #type' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value', params: { PAR1: 'p1' } })
            expect(p.to_s).to eql('NAME;PAR1=p1:value value')
            expect(p.type).to be_nil
            
            p.set_parameter(:value, 'DATE')
            expect(p.to_s).to eql('NAME;PAR1=p1;VALUE=DATE:value value')
            expect(p.type).to eql('DATE')
          end
        end

        context '#get_parameter' do
          it 'should return nil for an unknown parameter' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value' })
            expect(p.get_parameter(:par1)).to be_nil
          end

          it 'should return a known parameter' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value', params: { PAR1: 'p1' } })
            expect(p.get_parameter(:par1)).to eql('p1')
          end
        end
        
        context '#unset_parameter' do
          it 'should unset a parameter' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value', params: { PAR1: 'p1' } })
            expect(p.to_s).to eql('NAME;PAR1=p1:value value')

            p.unset_parameter(:par1)
            expect(p.to_s).to eql('NAME:value value')
          end
        end

        context '#type' do
          it 'should set the :VALUE parameter' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value' })
            expect(p.type).to be_nil
            expect(p.get_parameter(:value)).to be_nil
            expect(p.to_s).to eql('NAME:value value')
            
            p.type = 'DATE-TIME'
            expect(p.type).to eql('DATE-TIME')
            expect(p.get_parameter(:value)).to eql('DATE-TIME')
            expect(p.to_s).to eql('NAME;VALUE=DATE-TIME:value value')
          end

          it 'should unset the :VALUE parameter when set to nil' do
            p = Fl::Core::Icalendar::Property::Base.new({ name: 'name', value: 'value value', params: { value: 'DATE' } })
            expect(p.type).to eql('DATE')
            expect(p.get_parameter(:value)).to eql('DATE')
            expect(p.to_s).to eql('NAME;VALUE=DATE:value value')
            
            p.type = nil
            expect(p.type).to be_nil
            expect(p.get_parameter(:value)).to be_nil
            expect(p.to_s).to eql('NAME:value value')
          end
        end
      end

      context '.make_property' do
        it 'should create an instance of Fl::Core::Icalendar::Property::Dtend for DTEND' do
          s = 'DTEND;VALUE=DATE:19980704'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Dtend)
          expect(p.value).to eql('19980704')
          expect(p.type).to eql('DATE')
          dt1 = p.datetime
          dt2 = Fl::Core::Icalendar.parse('19980704')
          expect(dt1.to_i).to eql(dt2.to_i)

          s = 'DTEND:19980704'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Dtend)
          expect(p.value).to eql('19980704')
          expect(p.type).to eql('DATE')
          dt1 = p.datetime
          dt2 = Fl::Core::Icalendar.parse('19980704')
          expect(dt1.to_i).to eql(dt2.to_i)
        end

        it 'should create an instance of Fl::Core::Icalendar::Property::Due for DUE' do
          s = 'DUE:19980704'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Due)
          expect(p.value).to eql('19980704')
          expect(p.type).to eql('DATE')
          dt1 = p.datetime
          dt2 = Fl::Core::Icalendar.parse('19980704')
          expect(dt1.to_i).to eql(dt2.to_i)

          s = 'DUE:19980704T100000'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Due)
          expect(p.value).to eql('19980704T100000')
          expect(p.type).to eql('DATE-TIME')
          dt1 = p.datetime
          dt2 = Fl::Core::Icalendar.parse('19980704T100000')
          expect(dt1.to_i).to eql(dt2.to_i)
        end

        it 'should create an instance of Fl::Core::Icalendar::Property::Dtstart for DTSTART' do
          s = 'DTSTART;VALUE=DATE-TIME;TZID=America/Los_Angeles:19980704T1020'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Dtstart)
          expect(p.value).to eql('TZID=America/Los_Angeles:19980704T1020')
          expect(p.type).to eql('DATE-TIME')
          expect(p.tzid).to eql('America/Los_Angeles')
          dt1 = p.datetime
          dt2 = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:19980704T1020')
          expect(dt1.to_i).to eql(dt2.to_i)

          s = 'DTSTART;TZID=America/Los_Angeles;VALUE=DATE-TIME:19980704T1020'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Dtstart)
          expect(p.value).to eql('TZID=America/Los_Angeles:19980704T1020')
          expect(p.type).to eql('DATE-TIME')
          expect(p.tzid).to eql('America/Los_Angeles')
          dt1 = p.datetime
          dt2 = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:19980704T1020')
          expect(dt1.to_i).to eql(dt2.to_i)
        end
        
        it 'should create an instance of Fl::Core::Icalendar::Property::Base for GEO' do
          s = 'GEO:37.386013;-122.082932'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Base)
          expect(p.value).to eql('37.386013;-122.082932')
        end

        it 'should create an instance of Fl::Core::Icalendar::Property::Base for ATTACH' do
          s = 'ATTACH;FMTTYPE=application/postscript:ftp://example.com/pub/reports/r-960812.ps'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Base)
          x = {
            :name => 'ATTACH',
            :params => {
              :FMTTYPE => 'application/postscript'
            },
            :value => 'ftp://example.com/pub/reports/r-960812.ps'
          }
          expect(p.to_hash).to eql(x)
          expect(p.value).to eql('ftp://example.com/pub/reports/r-960812.ps')
        end

        it 'should create an instance of Fl::Core::Icalendar::Property::Location for LOCATION' do
          s = 'LOCATION:Conference Room - F123\, Bldg. 002'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Location)
          x = {
            :name => 'LOCATION',
            :params => {
            },
            :value => 'Conference Room - F123, Bldg. 002'
          }
          expect(p.to_hash).to eql(x)
          expect(p.value).to eql('Conference Room - F123, Bldg. 002')

          s = 'LOCATION;ALTREP="http://xyzcorp.com/conf-rooms/f123.vcf":Conference Room - F123\, Bldg. 002'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Location)
          x = {
            :name => 'LOCATION',
            :params => {
              :ALTREP => 'http://xyzcorp.com/conf-rooms/f123.vcf'
            },
            :value => 'Conference Room - F123, Bldg. 002'
          }
          expect(p.to_hash).to eql(x)
          expect(p.value).to eql('Conference Room - F123, Bldg. 002')
        end

        it 'should create an instance of Fl::Core::Icalendar::Property::Summary for SUMMARY' do
          s = 'SUMMARY:Here is a summary'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Summary)
          expect(p.value).to eql('Here is a summary')
        end

        it 'should create an instance of Fl::Core::Icalendar::Property::Url for URL' do
          s = 'URL:http://example.com/pub/calendars/jsmith/mytime.ics'
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Url)
          expect(p.value).to eql('http://example.com/pub/calendars/jsmith/mytime.ics')
        end

        it 'should create an instance of Fl::Core::Icalendar::Property::Description for DESCRIPTION' do
          d = 'Meeting to provide technical review for "Phoenix" design.\nHappy Face Conference Room. Phoenix design team MUST attend this meeting.\nRSVP to team leader.'
          s = "DESCRIPTION:#{d}"
          p = Fl::Core::Icalendar::Property::Base.make_property(s)
          expect(p.nil?).to eql(false)
          expect(p).to be_a_kind_of(Fl::Core::Icalendar::Property::Description)
          expect(p.value).to eql(d.gsub('\n', "\n"))
        end
      end
    end

    describe Fl::Core::Icalendar::Property::DateTime do
      context '.new' do
        it 'creates from a string datetime' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', '20140110T102030')
          expect(d.name).to eql('NAME')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to be_nil
          expect(d.value).to eql('20140110T102030')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME2', '20140110')
          expect(d.name).to eql('NAME2')
          expect(d.get_parameter(:VALUE)).to eql('DATE')
          expect(d.type).to eql('DATE')
          expect(d.tzid).to be_nil
          expect(d.value).to eql('20140110')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', 'TZID=America/Los_Angeles:20140110T102030')
          expect(d.name).to eql('NAME3')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to eql('America/Los_Angeles')
          expect(d.value).to eql('TZID=America/Los_Angeles:20140110T102030')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME4', '20140110T102030Z')
          expect(d.name).to eql('NAME4')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to eql('UTC')
          expect(d.value).to eql('20140110T102030Z')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME5', '20140110Z')
          expect(d.name).to eql('NAME5')
          expect(d.get_parameter(:VALUE)).to eql('DATE')
          expect(d.type).to eql('DATE')
          expect(d.tzid).to eql('UTC')
          expect(d.value).to eql('20140110Z')
        end

        it 'creates from a Datetime object' do
          dt = Fl::Core::Icalendar.parse('20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', dt)
          expect(d.name).to eql('NAME')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to eql('UTC')
          expect(d.value).to eql('20140110T182030Z')

          dt = Fl::Core::Icalendar.parse('20140110')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME2', dt)
          expect(d.name).to eql('NAME2')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to eql('UTC')
          expect(d.value).to eql('20140110T080000Z')

          dt = Fl::Core::Icalendar.parse('20140110')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME2', dt, { VALUE: 'DATE' })
          expect(d.name).to eql('NAME2')
          expect(d.get_parameter(:VALUE)).to eql('DATE')
          expect(d.type).to eql('DATE')
          expect(d.tzid).to eql('UTC')
          expect(d.value).to eql('20140110Z')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt)
          expect(d.name).to eql('NAME3')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to eql('UTC')
          expect(d.value).to eql('20140110T182030Z')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/Los_Angeles' })
          expect(d.name).to eql('NAME3')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to eql('America/Los_Angeles')
          expect(d.value).to eql('TZID=America/Los_Angeles:20140110T102030')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York' })
          expect(d.name).to eql('NAME3')
          expect(d.get_parameter(:VALUE)).to eql('DATE-TIME')
          expect(d.type).to eql('DATE-TIME')
          expect(d.tzid).to eql('America/New_York')
          expect(d.value).to eql('TZID=America/New_York:20140110T132030')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York', VALUE: 'DATE' })
          expect(d.name).to eql('NAME3')
          expect(d.get_parameter(:VALUE)).to eql('DATE')
          expect(d.type).to eql('DATE')
          expect(d.tzid).to eql('America/New_York')
          expect(d.value).to eql('TZID=America/New_York:20140110')
        end
      end
      
      context 'updates' do
        it 'should track the timezone when timezone changes from non-nil to non-nil' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
          expect(d.tzid).to eql('America/New_York')
          expect(d.value).to eql('TZID=America/New_York:20140110T102030')
          d.tzid = 'Europe/Rome'
          expect(d.tzid).to eql('Europe/Rome')
          expect(d.value).to eql('TZID=Europe/Rome:20140110T162030')
        end

        it 'should switch to floating when timezone changes from non-nil to nil' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
          expect(d.tzid).to eql('America/New_York')
          expect(d.value).to eql('TZID=America/New_York:20140110T102030')
          d.tzid = nil
          expect(d.tzid).to be_nil
          expect(d.value).to eql('20140110T102030')
        end

        it 'should anchor time when timezone changes from nil to non-nil' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
          d.tzid = nil
          expect(d.tzid).to be_nil
          d.tzid = 'Europe/Rome'
          expect(d.tzid).to eql('Europe/Rome')
          expect(d.value).to eql('TZID=Europe/Rome:20140110T102030')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', '20140110T102030')
          expect(d.tzid).to be_nil
          expect(d.value).to eql('20140110T102030')
          d.tzid = 'America/New_York'
          expect(d.tzid).to eql('America/New_York')
          expect(d.value).to eql('TZID=America/New_York:20140110T102030')
        end
        
        it 'should keep TYPE if new value has the same format as the old value' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
          expect(d.tzid).to eql('America/New_York')
          expect(d.type).to eql('DATE-TIME')
          expect(d.value).to eql('TZID=America/New_York:20140110T102030')
          d.value = '20140110T082030'
          expect(d.tzid).to eql('America/New_York')
          expect(d.type).to eql('DATE-TIME')
          expect(d.value).to eql('TZID=America/New_York:20140110T082030')
        end
        
        it 'should switch TYPE if new value has a different format from the old value' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
          expect(d.tzid).to eql('America/New_York')
          expect(d.type).to eql('DATE-TIME')
          expect(d.value).to eql('TZID=America/New_York:20140110T102030')
          d.value = '20140110'
          expect(d.tzid).to eql('America/New_York')
          expect(d.type).to eql('DATE')
          expect(d.value).to eql('TZID=America/New_York:20140110')
        end

        it 'should switch timezone if value contains a timezone qualifier' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
          expect(d.tzid).to eql('America/New_York')
          expect(d.type).to eql('DATE-TIME')
          expect(d.value).to eql('TZID=America/New_York:20140110T102030')
          d.value = 'TZID=Europe/Rome:20140110T062030'
          expect(d.tzid).to eql('Europe/Rome')
          expect(d.type).to eql('DATE-TIME')
          expect(d.value).to eql('TZID=Europe/Rome:20140110T062030')
        end
        
        it 'should switch timezone and TYPE if value contains a timezone qualifier and different format' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
          expect(d.tzid).to eql('America/New_York')
          expect(d.type).to eql('DATE-TIME')
          expect(d.value).to eql('TZID=America/New_York:20140110T102030')
          d.value = 'TZID=Europe/Rome:20140112'
          expect(d.tzid).to eql('Europe/Rome')
          expect(d.type).to eql('DATE')
          expect(d.value).to eql('TZID=Europe/Rome:20140112')
        end

        context 'setting value as a Time object' do
          it 'should not change the timezone' do
            d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE-TIME')
            expect(d.value).to eql('TZID=America/New_York:20140110T102030')

            # (the current timezone is America/Los_Angeles)

            d.value = Fl::Core::Icalendar.parse('20140110T082030')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE-TIME')
            expect(d.value).to eql('TZID=America/New_York:20140110T112030')

            d.value = Fl::Core::Icalendar.parse('TZID=Europe/Rome:20140110T082030')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE-TIME')
            expect(d.value).to eql('TZID=America/New_York:20140110T022030')
          end

          it 'should not change TYPE if TYPE is already defined' do
            d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110T102030')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE-TIME')
            expect(d.value).to eql('TZID=America/New_York:20140110T102030')

            d.value = Fl::Core::Icalendar.parse('20140110')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE-TIME')
            expect(d.value).to eql('TZID=America/New_York:20140110T030000')

            d.value = Fl::Core::Icalendar.parse('TZID=Europe/Rome:20140110')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE-TIME')
            expect(d.value).to eql('TZID=America/New_York:20140109T180000')

            d = Fl::Core::Icalendar::Property::DateTime.new('NAME', 'TZID=America/New_York:20140110')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE')
            expect(d.value).to eql('TZID=America/New_York:20140110')

            d.value = Fl::Core::Icalendar.parse('TZID=Europe/Rome:20140110')
            expect(d.tzid).to eql('America/New_York')
            expect(d.type).to eql('DATE')
            expect(d.value).to eql('TZID=America/New_York:20140109')
          end
        end
      end

      context '.to_s' do
        it 'converts correctly' do
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', '20140110T102030')
          expect(d.to_s).to eql('NAME;VALUE=DATE-TIME:20140110T102030')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME2', '20140110')
          expect(d.to_s).to eql('NAME2;VALUE=DATE:20140110')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', 'TZID=America/Los_Angeles:20140110T102030')
          expect(d.to_s).to eql('NAME3;VALUE=DATE-TIME:TZID=America/Los_Angeles:20140110T102030')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME4', '20140110T102030Z')
          expect(d.to_s).to eql('NAME4;VALUE=DATE-TIME:20140110T102030Z')

          d = Fl::Core::Icalendar::Property::DateTime.new('NAME5', '20140110Z')
          expect(d.to_s).to eql('NAME5;VALUE=DATE:20140110Z')

          dt = Fl::Core::Icalendar.parse('20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME', dt)
          expect(d.to_s).to eql('NAME;VALUE=DATE-TIME:20140110T182030Z')

          dt = Fl::Core::Icalendar.parse('20140110')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME2', dt)
          expect(d.to_s).to eql('NAME2;VALUE=DATE-TIME:20140110T080000Z')

          dt = Fl::Core::Icalendar.parse('20140110')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME2', dt, { :VALUE => 'DATE' })
          expect(d.to_s).to eql('NAME2;VALUE=DATE:20140110Z')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt)
          expect(d.to_s).to eql('NAME3;VALUE=DATE-TIME:20140110T182030Z')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/Los_Angeles' })
          expect(d.to_s).to eql('NAME3;VALUE=DATE-TIME:TZID=America/Los_Angeles:20140110T102030')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York' })
          expect(d.to_s).to eql('NAME3;VALUE=DATE-TIME:TZID=America/New_York:20140110T132030')

          dt = Fl::Core::Icalendar.parse('TZID=America/Los_Angeles:20140110T102030')
          d = Fl::Core::Icalendar::Property::DateTime.new('NAME3', dt, { :TZID => 'America/New_York', :VALUE => 'DATE' })
          expect(d.to_s).to eql('NAME3;VALUE=DATE:TZID=America/New_York:20140110')
        end
      end
    end
  end

  describe Fl::Core::Icalendar::Datetime do
    # this also indirectly tests .parse
    
    context '.new' do
      it 'should accept a string datetime value with Z qualifier' do
        dt = Fl::Core::Icalendar::Datetime.new('20140210T102030Z')
        expect(dt.valid?).to eql(true)
        expect(dt.timezone).to eql('UTC')
        expect(dt.date).to eql('20140210')
        expect(dt.time).to eql('102030')
        expect(dt.type).to eql(Fl::Core::Icalendar::DATETIME)
        h = { :TZID => 'UTC', :DATE => '20140210', :TIME => '102030' }
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('20140210T102030Z')
        tz  = ActiveSupport::TimeZone.new('UTC')
        t = tz.parse('20140210T102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
        dt.timezone = 'America/Los_Angeles'
        tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
        t = tz.parse('20140210T102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
      end
      
      it 'should accept a string date value with Z qualifier' do
        dt = Fl::Core::Icalendar::Datetime.new('20140210Z')
        expect(dt.valid?).to be(true)
        expect(dt.timezone).to eql('UTC')
        expect(dt.date).to eql('20140210')
        expect(dt.time).to be_nil
        expect(dt.type).to eql(Fl::Core::Icalendar::DATE)
        h = { :TZID => 'UTC', :DATE => '20140210' }
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('20140210Z')
        tz  = ActiveSupport::TimeZone.new('UTC')
        t = tz.parse('20140210T000000')
        expect(dt.to_time.to_i).to eql(t.to_i)
        dt.timezone = 'America/Los_Angeles'
        tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
        t = tz.parse('20140210T000000')
        expect(dt.to_time.to_i).to eql(t.to_i)
      end
      
      it 'should accept a string time value with Z qualifier' do
        dt = Fl::Core::Icalendar::Datetime.new('102030Z')
        expect(dt.valid?).to eql(true)
        expect(dt.timezone).to eql('UTC')
        expect(dt.date).to be_nil
        expect(dt.time).to eql('102030')
        expect(dt.type).to eql(Fl::Core::Icalendar::TIME)
        h = { :TZID => 'UTC', :TIME => '102030' }
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('102030Z')
        tz  = ActiveSupport::TimeZone.new('UTC')
        t = tz.parse(self.today(tz) + '102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
        dt.timezone = 'America/Los_Angeles'
        tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
        t = tz.parse(self.today(tz) + '102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
      end
      
      it 'should accept a string datetime value with timezone qualifier' do
        dt = Fl::Core::Icalendar::Datetime.new('TZID=America/New_York:20140210T102030')
        expect(dt.valid?).to eql(true)
        expect(dt.timezone).to eql('America/New_York')
        expect(dt.date).to eql('20140210')
        expect(dt.time).to eql('102030')
        expect(dt.type).to eql(Fl::Core::Icalendar::DATETIME)
        h = { :TZID => 'America/New_York', :DATE => '20140210', :TIME => '102030' }
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('TZID=America/New_York:20140210T102030')
        tz  = ActiveSupport::TimeZone.new('America/New_York')
        t = tz.parse('20140210T102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
        dt.timezone = 'America/Los_Angeles'
        tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
        t = tz.parse('20140210T102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
      end
      
      it 'should accept a string date value with timezone qualifier' do
        dt = Fl::Core::Icalendar::Datetime.new('TZID=America/New_York:20140210')
        expect(dt.valid?).to eql(true)
        expect(dt.timezone).to eql('America/New_York')
        expect(dt.date).to eql('20140210')
        expect(dt.time).to be_nil
        expect(dt.type).to eql(Fl::Core::Icalendar::DATE)
        h = { :TZID => 'America/New_York', :DATE => '20140210' }
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('TZID=America/New_York:20140210')
        tz  = ActiveSupport::TimeZone.new('America/New_York')
        t = tz.parse('20140210T000000')
        expect(dt.to_time.to_i).to eql(t.to_i)
        dt.timezone = 'America/Los_Angeles'
        tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
        t = tz.parse('20140210T000000')
        expect(dt.to_time.to_i).to eql(t.to_i)
      end
      
      it 'should accept a string time value with timezone qualifier' do
        dt = Fl::Core::Icalendar::Datetime.new('TZID=America/New_York:102030')
        expect(dt.valid?).to eql(true)
        expect(dt.timezone).to eql('America/New_York')
        expect(dt.date).to be_nil
        expect(dt.time).to eql('102030')
        expect(dt.type).to eql(Fl::Core::Icalendar::TIME)
        h = { :TZID => 'America/New_York', :TIME => '102030' }
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('TZID=America/New_York:102030')
        tz  = ActiveSupport::TimeZone.new('America/New_York')
        t = tz.parse(self.today(tz) + '102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
        dt.timezone = 'America/Los_Angeles'
        tz  = ActiveSupport::TimeZone.new('America/Los_Angeles')
        t = tz.parse(self.today(tz) + '102030')
        expect(dt.to_time.to_i).to eql(t.to_i)
      end
      
      it 'should accept a (UNIX) timestamp value' do
        utc_tz = ActiveSupport::TimeZone.create('UTC')
        t = utc_tz.parse('2014-08-12 10:20:30')
        dt = Fl::Core::Icalendar::Datetime.new(t.to_i)
        expect(dt.valid?).to eql(true)
        expect(dt.timezone).to eql('UTC')
        expect(dt.date).to eql('20140812')
        expect(dt.time).to eql('102030')
        expect(dt.type).to eql(Fl::Core::Icalendar::DATETIME)
        h = { :TZID => 'UTC', :DATE => '20140812', :TIME => '102030' }
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('20140812T102030Z')
      end

      it 'should accept a hash' do
        parsed = Fl::Core::Icalendar::Datetime.parse('TZID=America/New_York:20160416T102030')
        h = { TZID: 'America/New_York', DATE: '20160416', TIME: '102030' }
        expect(parsed).to eql(h)
        dt = Fl::Core::Icalendar::Datetime.new(parsed)
        expect(dt.valid?).to eql(true)
        expect(dt.timezone).to eql('America/New_York')
        expect(dt.date).to eql('20160416')
        expect(dt.time).to eql('102030')
        expect(dt.type).to eql(Fl::Core::Icalendar::DATETIME)
        expect(dt.components).to eql(h)
        expect(dt.to_hash).to eql(h)
        expect(dt.to_s).to eql('TZID=America/New_York:20160416T102030')
      end

      it 'should accept RFC 3339 format' do
        s_3339 = '2016-02-10T10:20:40-05:00'
        dt = Fl::Core::Icalendar::Datetime.new(s_3339)
        dth = { :DATE => '20160210', :TIME => '102040', :TZOFFSET => -300 }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)

        s_3339 = '2016-08-10T10:20:40-05:00'
        dt = Fl::Core::Icalendar::Datetime.new(s_3339)
        dth = { :DATE => '20160810', :TIME => '102040', :TZOFFSET => -300 }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)

        s_3339 = '2016-02-10'
        dt = Fl::Core::Icalendar::Datetime.new(s_3339)
        dth = { :DATE => '20160210' }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to be_nil
      end
      
      it 'should accept RFC 5545 format' do
        s_5545 = 'TZID=America/New_York:20160210T102040'
        dt = Fl::Core::Icalendar::Datetime.new(s_5545)
        dth = { :DATE => '20160210', :TIME => '102040', :TZID => 'America/New_York' }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)
        
        s_5545 = 'TZID=America/New_York:20160810T102040'
        dt = Fl::Core::Icalendar::Datetime.new(s_5545)
        dth = { :DATE => '20160810', :TIME => '102040', :TZID => 'America/New_York' }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)

        s_5545 = '20160210'
        dt = Fl::Core::Icalendar::Datetime.new(s_5545)
        dth = { :DATE => '20160210' }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to be_nil

        s_5545 = 'TZID=America/New_York:20160210'
        dt = Fl::Core::Icalendar::Datetime.new(s_5545)
        dth = { :DATE => '20160210', :TZID => 'America/New_York' }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)
      end
      
      it 'should accept RFC 5545 format with timezone offset (not standard)' do
        s_5545 = '20160210T102040 -05:00'
        dt = Fl::Core::Icalendar::Datetime.new(s_5545)
        dth = { :DATE => '20160210', :TIME => '102040', :TZOFFSET => -300 }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)
        
        s_5545 = '20160810T102040-0500'
        dt = Fl::Core::Icalendar::Datetime.new(s_5545)
        dth = { :DATE => '20160810', :TIME => '102040', :TZOFFSET => -300 }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)

        s_5545 = '20160210 -05:00'
        dt = Fl::Core::Icalendar::Datetime.new(s_5545)
        dth = { :DATE => '20160210', :TZOFFSET => -300 }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)
      end

      it 'should accept a Time object' do
        t = Time.parse('2016-02-10T10:20:40-05:00')
        dt = Fl::Core::Icalendar::Datetime.new(t)
        dth = { :DATE => '20160210', :TIME => '102040', :TZOFFSET => -300 }
        expect(dt.to_hash).to eql(dth)
        expect(dt.timezone_offset).to eql(-300)
      end
    end

    context '#to_rfc3339' do
      it 'should return RFC 3339 format' do
        s_3339 = '2016-02-10T10:20:40-05:00'
        dth = { :DATE => '20160210', :TIME => '102040', :TZOFFSET => -300 }
        dt = Fl::Core::Icalendar::Datetime.new(dth)
        expect(dt.to_rfc3339).to eql(s_3339)

        s_3339 = '2016-08-10T10:20:40-05:00'
        dth = { :DATE => '20160810', :TIME => '102040', :TZOFFSET => -300 }
        dt = Fl::Core::Icalendar::Datetime.new(dth)
        expect(dt.to_rfc3339).to eql(s_3339)

        s_3339 = '2016-02-10'
        dth = { :DATE => '20160210' }
        dt = Fl::Core::Icalendar::Datetime.new(dth)
        expect(dt.to_rfc3339).to eql(s_3339)
      end
    end

    context '#to_rfc5545' do
      it 'should return RFC 5545 format' do
        s_5545 = 'TZID=America/New_York:20160210T102040'
        dth = { :DATE => '20160210', :TIME => '102040', :TZID => 'America/New_York' }
        dt = Fl::Core::Icalendar::Datetime.new(dth)
        expect(dt.to_rfc5545).to eql(s_5545)
        
        s_5545 = 'TZID=America/New_York:20160810T102040'
        dth = { :DATE => '20160810', :TIME => '102040', :TZID => 'America/New_York' }
        dt = Fl::Core::Icalendar::Datetime.new(dth)
        expect(dt.to_rfc5545).to eql(s_5545)

        s_5545 = '20160210'
        dth = { :DATE => '20160210' }
        dt = Fl::Core::Icalendar::Datetime.new(dth)
        expect(dt.to_rfc5545).to eql(s_5545)

        s_5545 = 'TZID=America/New_York:20160210'
        dth = { :DATE => '20160210', :TZID => 'America/New_York' }
        dt = Fl::Core::Icalendar::Datetime.new(dth)
        expect(dt.to_rfc5545).to eql(s_5545)
      end
    end
    
    context '.valid? and .well_formed?' do
      it 'should be well formed and valid on a correct representation' do
        dt = Fl::Core::Icalendar::Datetime.new('20140110T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
      end

      it 'should be not well formed and not valid on a malformed representation' do
        dt = Fl::Core::Icalendar::Datetime.new('2014001T102030Z')
        expect(dt.well_formed?).to eql(false)
        expect(dt.valid?).to eql(false)

        # no second component: malformed

        dt = Fl::Core::Icalendar::Datetime.new('20140101T1020Z')
        expect(dt.well_formed?).to eql(false)
        expect(dt.valid?).to eql(false)
      end

      it 'should be well formed and not valid if month has value 13' do
        dt = Fl::Core::Icalendar::Datetime.new('20141310T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      end
      
      it 'should be well formed and not valid if day has value 0' do
        dt = Fl::Core::Icalendar::Datetime.new('20140100T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      end

      it 'should be well formed and not valid if day value is larger than month allows' do
        dt = Fl::Core::Icalendar::Datetime.new('20140131T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140132T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      
        dt = Fl::Core::Icalendar::Datetime.new('20140228T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140229T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20000228T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20000229T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20000230T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
        dt = Fl::Core::Icalendar::Datetime.new('19000228T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('19000229T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140331T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140332T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140430T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140431T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140531T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140532T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140630T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140631T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140731T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140732T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140831T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140832T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140930T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20140931T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20141031T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20141032T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20141130T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20141131T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20141231T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
        dt = Fl::Core::Icalendar::Datetime.new('20141232T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      end
      
      it 'should be well formed and not valid if hour value is larger than 23' do
        dt = Fl::Core::Icalendar::Datetime.new('20140101T242030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140101T282030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      end
      
      it 'should be well formed and not valid if minute value is larger than 59' do
        dt = Fl::Core::Icalendar::Datetime.new('20140101T106030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140101T106830Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      end
      
      it 'should be well formed and not valid if second value is larger than 59' do
        # (we ignore leap seconds)

        dt = Fl::Core::Icalendar::Datetime.new('20140101T102060Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)

        dt = Fl::Core::Icalendar::Datetime.new('20140101T102066Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      end
      
      it 'should be well formed and valid if timezone is OK' do
        dt = Fl::Core::Icalendar::Datetime.new('TZID=America/Los_Angeles:20140101T102030')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)

        # 'Z' timezone

        dt = Fl::Core::Icalendar::Datetime.new('20140101T102030Z')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
      end
      
      it 'should be well formed and valid if timezone is not provided' do
        dt = Fl::Core::Icalendar::Datetime.new('20140101T102030')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(true)
      end
      

      it 'should be well formed and valid if timezone is unknown or not valid' do
        dt = Fl::Core::Icalendar::Datetime.new('TZID=America/Menlo_Park:20140101T102030')
        expect(dt.well_formed?).to eql(true)
        expect(dt.valid?).to eql(false)
      end
    end
    
    context ".parse_tzoffset" do
      it 'should handle HH:MM notation correctly' do
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-08:00')).to eql(-480)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+08:00')).to eql(480)

        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-05:00')).to eql(-300)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+05:00')).to eql(300)

        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-01:30')).to eql(-90)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+01:30')).to eql(90)

        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-00:00')).to eql(0)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+00:00')).to eql(0)
      end

      it 'should handle HHMM notation correctly' do
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-0800')).to eql(-480)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+0800')).to eql(480)

        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-0500')).to eql(-300)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+0500')).to eql(300)

        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-0130')).to eql(-90)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+0130')).to eql(90)

        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('-0000')).to eql(0)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('+0000')).to eql(0)
      end
      
      it 'should be lenient of leading and trailing whitespace' do
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset(' -08:00 ')).to eql(-480)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('    +08:00     ')).to eql(480)

        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset(' -0800 ')).to eql(-480)
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('    +0800     ')).to eql(480)
      end
      
      it 'should return nil for 00:00' do
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('00:00')).to be_nil
      end

      it 'should return nil for out of range values' do
        expect(Fl::Core::Icalendar::Datetime.parse_tzoffset('22:00')).to be_nil
      end
    end

    context '.format_tzoffset' do
      it 'should format in-range values correctly' do
        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(-480)).to eql('-08:00')
        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(480)).to eql('+08:00')

        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(-300)).to eql('-05:00')
        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(300)).to eql('+05:00')

        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(-90)).to eql('-01:30')
        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(90)).to eql('+01:30')

        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(0)).to eql('+00:00')
      end

      it 'should return nil for out of range values' do
        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(-1000)).to be_nil
        expect(Fl::Core::Icalendar::Datetime.format_tzoffset(1000)).to be_nil
      end
    end

    context '#timezone_offset=' do
      it 'should change the offset' do
        s = '2016-02-10T10:20:40-05:00'
        dt = Fl::Core::Icalendar::Datetime.new(s)
        expect(dt.timezone_offset).to eql(-300)
        ts_0500 = dt.to_i
        expect(ts_0500).to eql(Time.parse(s).to_i)
        expect(dt.to_rfc3339).to eql(s)

        dt.timezone_offset = '-07:00'
        expect(dt.timezone_offset).to eql(-420)
        ts_0700 = dt.to_i
        expect(ts_0500 - ts_0700).to eql((-120 * 60))
        expect(dt.to_rfc3339).to eql('2016-02-10T10:20:40-07:00')
      end
    end

    context '#timezone=' do
      it 'should change the timezone and offset)' do
        s = '2016-02-10T10:20:40-05:00'
        dt = Fl::Core::Icalendar::Datetime.new(s)
        ts_0500 = dt.to_i

        dt.timezone = 'America/Los_Angeles'
        ts_ca = dt.to_i
        expect(ts_0500 - ts_ca).to eql((-180 * 60))
      end
    end
  end
end
