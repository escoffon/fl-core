module Fl::Core
  # A namespace for RFC 5545 (iCalendar) utilities.

  module Icalendar
    # @!visibility private
    DATETIME = 'DATE-TIME'

    # @!visibility private
    DATE = 'DATE'

    # @!visibility private
    TIME = 'TIME'

    # @!visibility private
    NONE = 'NONE'

    # Given a string containing a datetime, split the TZID (if any) and actual datetime.
    #
    # @param [String] datetime A string containing a datetime, including a timezone identifier either
    #  in the TZID format, or as the +Z+ suffix.
    #
    # @return [Array<String>] Returns a two element array containing the datetime and timezone.

    def self.split_datetime(datetime)
      if datetime =~ /^\s*TZID=([^:]+):(.*)/
        m = Regexp.last_match
        tz = m[1]
        dt = m[2]
      else
        tz = nil
        dt = datetime
      end

      # A Z suffix forces the timezone to UTC

      if datetime.end_with?('Z')
        tz = 'UTC'
        dt = datetime[0, datetime.length-1]
      end

      [ dt, tz ]
    end

    # Given a string containing a datetime and an optional timezone name, generate a datetime string.
    #
    # @param [String] datetime A string containing a datetime.
    # @param [String, ActiveSupport::TimeZone] tz An optional timezone name (or ActiveSupport::TimeZone object, from which the name is
    #  extracted).
    #  +UTC+ and +GMT+ are converted to the +Z+ suffix; others are expressed via the **TZID** parameter.
    #
    # @return [String] Returns a string containing the datetime.

    def self.join_datetime(datetime, tz = nil)
      if tz
        tzname = (tz.is_a?(ActiveSupport::TimeZone)) ? tz.name : tz

        if (tzname.casecmp('UTC') == 0) || (tzname.casecmp('GMT') == 0) || (tzname.casecmp('Z') == 0)
          datetime + 'Z'
        else
          'TZID=' + tzname + ':' + datetime
        end
      else
        datetime
      end
    end

    # Check if a string contains a DATE-TIME, DATE, or TIME (or none of the above).
    # This method can also be used to check if a datetime string is well formed.
    # A well formed string starts with an optional +TZID+ identifier, followed by a datetime
    # stamp in RFC 5545 format (yyyymmddThhMMss), and an optional UTC identifier (Z).
    #
    # @param [String] datetime A string to check.
    #
    # @return [String] Returns one of three values, as follows. First, drop the timezone identifier if present.
    #  Then, if the string contains 8 integers, the literal +T+, and 4 or 6 integers, returns
    #  'DATE-TIME'. If the string contains 8 integers, returns 'DATE'.
    #  If the string contains 4 or 6 integers, returns 'TIME'. In all other cases, returns 'NONE'.

    def self.date_type(datetime)
      return Fl::Core::Icalendar::NONE unless datetime.is_a?(String)

      dt, tz = Fl::Core::Icalendar.split_datetime(datetime)

      if tz && (tz != 'Z')
        # If we were given a TZID, it must be a valid timezone name

        return Fl::Core::Icalendar::NONE unless ActiveSupport::TimeZone.new(tz)
      end

      if dt =~ /^([0-9]{8})T([0-9]{4,6})$/
        m = Regexp.last_match
        if (m[2].length == 4) || (m[2].length == 6)
          Fl::Core::Icalendar::DATETIME
        else
          Fl::Core::Icalendar::NONE
        end
      elsif dt =~ /^[0-9]{4,8}$/
        if dt.length == 8
          Fl::Core::Icalendar::DATE
        elsif (dt.length == 4) || (dt.length == 6)
          Fl::Core::Icalendar::TIME
        end
      else
        Fl::Core::Icalendar::NONE
      end
    end

    # Format a Time object into a DATE-TIME string.
    #
    # @param [String] datetime The Time object.
    #
    # @return [String] Returns a string in the format +yyyymmddThhmmss+.

    def self.format_datetime(datetime)
      datetime.strftime('%Y%m%dT%H%M%S')
    end

    # Format a Time object into a DATE string.
    #
    # @param [Time] datetime The Time object.
    #
    # @return [String] Returns a string in the format +yyyymmdd+.

    def self.format_date(datetime)
      datetime.strftime('%Y%m%d')
    end

    # Format a Time object into a TIME string.
    #
    # @param [Time] datetime The Time object.
    #
    # @return [String] Returns a string in the format +hhmmss+.

    def self.format_time(datetime)
      datetime.strftime('%H%M%S')
    end

    # Parse a datetime string representation and generate a Time object.
    #
    # @param [String] datetime A string containing an RFC 5545 DATE-TIME or DATE value, possibly including
    #  a timezone specifier.
    #
    # @return [Time] Returns a Time object in the given timezone, or in the local timezone.
    #  If _datetime_ includes an invalid timezone name, the return value is +nil+.
    #  (An invalid timezone is not part of the known set of timezones in Active Support.)

    def self.parse(datetime)
      if datetime =~ /^\s*TZID=([^:]+):(.*)/
        m = Regexp.last_match
        tz = ActiveSupport::TimeZone.new(m[1])
        (tz.nil?) ? nil : tz.parse(m[2])
      elsif datetime =~ /(.*)[zZ]$/
        m = Regexp.last_match
        tz = ActiveSupport::TimeZone.new('UTC')
        tz.parse(m[1])
      else
        Time.zone.parse(datetime)
      end
    end

    # Convert a datetime to a different timezone.
    #
    # @param [String] datetime A string containing an RFC 5545 datetime (possibly including the timezone),
    #  or a Time object.
    # @param [String, ActiveSupport::TimeZone] tz The timezone to which to convert; can be a string or a ActiveSupport::TimeZone object.
    #
    # @return [String] Returns a string containing the datetime in the new timezone; this string includes the
    #  timezone identifier.

    def self.in_time_zone(datetime, tz)
      dt = if datetime.is_a?(Time)
             datetime
           else
             Fl::Core::Icalendar.parse(datetime)
           end
      Fl::Core::Icalendar.join_datetime(Fl::Core::Icalendar.format_datetime(dt.in_time_zone(tz)), tz)
    end

    # Get a Time object close to the last supported (32 bit) UNIX timestamp value.
    # At 03:14:08 UTC on 19 January 2038, signed 32-bit UNIX timestamps will overflow; we
    # return a number close to that. By then, this code most assuredly will have long since ceased
    # to be used anywhere. And if not, some poor sot will have to deal with it.
    #
    # @return [Time] Returns a Time instance for 20380101T000000Z.

    def self.end_of_32bit_time()
      Fl::Core::Icalendar.parse('20380101T000000Z')
    end

    # Get a Time object for the start of UNIX time.
    #
    # @return [Time] Returns a Time instance for 19700101T000000Z.

    def self.start_of_time()
      Fl::Core::Icalendar.parse('19700101T000000')
    end

    # Convert a datetime argument to a Time object.
    #
    # @param [String, Datetime, Time] datetime A datetime. This is a string containing a datetime
    #  in RFC 5545 format, a {Datetime} object, or a Time object.
    #
    # @return [Time] Returns a Time object for _datetime_.

    def self.datetime_to_time(datetime)
      if datetime.is_a?(Time)
        datetime
      elsif datetime.is_a?(Fl::Core::Icalendar::Datetime)
        datetime.to_time
      else
        Fl::Core::Icalendar::Datetime.new(datetime).to_time
      end
    end

    # A class to store the parsed representation of a datetime.
    # See the documentation for the {#to_hash} method for a description of the parsed representation.

    class Datetime
      # @!visibility private
      DAY_MONTH = [ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]

      # Initializer.
      #
      # @overload initialize(datetime = nil)
      #  Initializes the object from a string value.
      #  @param datetime [String] A string representation of the datetime.
      #   See {Fl::Core::Icalendar::Datetime.parse} for details.
      # @overload initialize(t = nil)
      #  Initializes the object from a Time object.
      #  @param t [Time] A Time object; the object type is set to +DATETIME+, and the timezone offset
      #   is set to the local timezone offset.
      # @overload initialize(ts = nil)
      #  Initializes the object from a UNIX timestamp.
      #  @param ts [Integer] An integer containing a UNIX timestamp; the object type is set to +DATETIME+,
      #   and the timezone to UTC.
      # @overload initialize(data = nil)
      #  Initializes the object from a hash representation of the datetime.
      #  @param data [Hash] A Hash containing a representation of the datetime.
      #  @option data [String] :TZID The timezone identifier; +Z+ is a valid input value, and will be
      #   converted to +UTC+. If this key is not present, the datetime represents a floating datetime.
      #  @option data [String] :TZOFFSET Alternatively to **:TZID**, this key has a string containing the offset
      #   from UTC in hours and minutes (for example: -08:00 or +01:30). Note that **:TZID** and **:TZOFFSET**
      #   are mutually exclusive.
      #  @option data [String] :DATE The date component, in RFC 5545 format. If not present, this is a +TIME+
      #   datetime value.
      #  @option data [String] :TIME The time component, in RFC 5545 format. If not present, this is a +DATE+
      #   datetime value.

      def initialize(data = nil)
        if data.is_a?(String)
          @hash = Fl::Core::Icalendar::Datetime.parse(data)
        elsif data.is_a?(Integer)
          tz = ActiveSupport::TimeZone.create('UTC')
          a = tz.at(data).to_a
          @hash = {
            :TZID => 'UTC',
            :DATE => sprintf('%4d%02d%02d', a[5], a[4], a[3]),
            :TIME => sprintf('%02d%02d%02d', a[2], a[1], a[0])
          }
        elsif data.is_a?(Time)
          @hash = Fl::Core::Icalendar::Datetime.parse(data.rfc3339)
        elsif data.is_a?(Hash)
          unless Fl::Core::Icalendar::Datetime.valid?(data)
            @hash = nil
          else
            @hash = {}
            @hash[:TZID] = data[:TZID] if data.has_key?(:TZID)
            @hash[:TZOFFSET] = data[:TZOFFSET] if data.has_key?(:TZOFFSET)
            @hash[:DATE] = data[:DATE] if data.has_key?(:DATE)
            @hash[:TIME] = data[:TIME] if data.has_key?(:TIME)
          end
        end
      end

      # Get the datetime components.
      #
      # @return [Hash] Returns a hash containing the three keys **:TZID**, **:DATE**, and **:TIME**
      #  (some may be missing). If it returns +nil+, the datetime is not valid.

      def components()
        @hash
      end

      # Is a datetime hash well formed?
      # The hash is well formed if:
      #
      # 1. It contains one of DATE or TIME components, or both.
      # 2. The DATE component, if any, is a sequence of 8 digits (e.g. 20140210).
      # 3. The TIME component, if any, is a sequence of 6 digits (e.g. 102030).
      # A well formed hash may contain illegal values for the components, for example a value for hours
      # larger than 23.
      #
      # @param [Hash] hash The hash to check.
      #
      # @return [Boolean] Returns +true+ if the hash is well formed, +false+ otherwise.

      def self.well_formed?(hash)
        return false unless hash.has_key?(:DATE) || hash.has_key?(:TIME)

        if hash.has_key?(:DATE)
          return false unless hash[:DATE] =~ /^[0-9]{8}$/
        end

        if hash.has_key?(:TIME)
          return false unless hash[:TIME] =~ /^[0-9]{6}$/
        end

        return true
      end

      # Is the datetime well formed?
      # A well formed datetime was parsed correctly, but may contain illegal values for the
      # components, for example a value for hours larger than 23.
      #
      # This method calls the class method by the same name.
      #
      # @return [Boolean] Returns +true+ if the datetime is well formed, +false+ otherwise.

      def well_formed?()
        if @hash
          self.class.well_formed?(@hash)
        else
          false
        end
      end

      private

      def self.leap?(year)
        if (year % 4) != 0
          # not divisible by 4: not a leap year

          false
        else
          if (year % 100) != 0
            # not divisible by 100: leap year

            true
          else
            # divisible by 400: leap year
            # not divisible by 400: not a leap year

            ((year % 400) == 0) ? true : false
          end
        end
      end

      def self.day_month(month, year)
        dm = DAY_MONTH[month]
        dm += 1 if (month == 2) && leap?(year)
        dm
      end

      public

      # Ordering operator.
      # Compares two {Datetime} objects by comparing their integer representation (which is
      # an offset from a given anchor in time).
      #
      # @param [Datetime] other The other object to compare.
      #
      # @return [Integer] Returns -1 if +self+ is earlier than _other_, 0 if they are the same time,
      #  and +1 if +self+ is later than _other_.

      def <=>(other)
        return nil unless other.is_a?(Fl::Core::Icalendar::Datetime)
        self.to_i <=> other.to_i
      end

      # Is a timezone valid?
      # A valid timezone is in the TZInfo list for ActiveSupport.
      #
      # @param [String] timezone The timezone to check.
      #
      # @return [Boolean] Returns +true+ if the timezone is valid, +false+ otherwise.

      def self.valid_timezone?(timezone)
        ActiveSupport::TimeZone.new(timezone).nil? ? false : true
      end

      # Is the datetime hash valid?
      # A valid datetime hash is well formed. It also satisfies the following additional constraints:
      #
      # 1. The month value in the DATE component is between 1 and 12.
      # 2. The day value in the DATE component is between the appropriate values for the
      #    given month (and year).
      # 3. The hour value in the TIME component is between 0 and 23.
      # 4. The minute value in the TIME component is between 0 and 59.
      # 5. The second value in the TIME component is between 0 and 59. Note that we don't allow leap seconds.
      # 6. The timezone in the TZID component, if any, must be a valid timezone.
      #
      # @param [Hash] hash The hash to check.
      #
      # @return [Boolean] Returns +true+ if the hash is valid, +false+ otherwise.

      def self.valid?(hash)
        return false unless well_formed?(hash)

        if hash[:DATE]
          date = hash[:DATE]

          year = date[0,4].to_i

          month = date[4,2].to_i
          return false if (month < 1) || (month > 12)

          day = date[6,2].to_i
          return false if (day < 1) || (day > day_month(month, year))
        end

        if hash[:TIME]
          time = hash[:TIME]

          hour = time[0,2].to_i
          return false if hour > 23

          minute = time[2,2].to_i
          return false if minute > 59

          second = time[4,2].to_i
          return false if second > 59
        end

        if hash[:TZID]
          return false unless valid_timezone?(hash[:TZID])
        end

        true
      end

      # Is the datetime valid?
      # First, calls {.well_formed?} to ensure that the datetime is well formed.
      # Then, calls the class method by the same name, passing the datetime's hash of components.
      #
      # @return Returns +true+ if the datetime is well formed, +false+ otherwise.

      def valid?()
        return false unless well_formed?()

        self.class.valid?(@hash)
      end

      # Get the timezone component, if any.
      #
      # @return [String] Returns the timezone component (the timezone name), if any.

      def timezone()
        if @hash
          @hash[:TZID]
        else
          nil
        end
      end

      # Set the timezone component.
      # Setting the timezone removes the **:TZOFFSET** component if one is present.
      #
      # @param tz The name of the timezone to use; it must be a valid timezone name in TZInfo.
      #
      # @raise [ArgumentError] Raised if the timezone is not valid.
      # @raise [RuntimeError] Raised if the datetime is not valid.

      def timezone=(tz)
        raise RuntimeError.new('the target datetime object is invalid') unless @hash
        raise ArgumentError.new("invalid timezone: #{tz}") unless ActiveSupport::TimeZone.new(tz)

        @hash[:TZID] = tz
        @hash.delete(:TZOFFSET)
      end

      # Get the timezone offset component, if any.
      # This is the offset, in minutes, from UTC.
      #
      # @return [String] Returns the timezone offset component (**:TZOFFSET**), if any.
      #  If the component is not present, but **:TZID** is present, get the offset from the timezone.
      #  Either way, the offset is returned in minutes.

      def timezone_offset()
        if @hash
          if @hash.has_key?(:TZOFFSET)
            @hash[:TZOFFSET]
          elsif @hash.has_key?(:TZID)
            tz = ActiveSupport::TimeZone.new(@hash[:TZID])
            (tz) ? (tz.utc_offset / 60) : nil
          else
            nil
          end
        else
          nil
        end
      end

      # Set the timezone offset component.
      # Setting the timezone removes the **:TZID** component if one is present.
      #
      # @param [String, Number] tzoff The timezone offset to use; it must be a valid timezone offset value,
      #  either a valid string, or a valid numeric value.
      #
      # @raise [ArgumentError] Raised if the timezone offset is not valid.
      # @raise [RuntimeError] Raised if the datetime is not valid.

      def timezone_offset=(tzoff)
        raise RuntimeError.new('the target datetime object is invalid') unless @hash

        if tzoff.is_a?(String)
          offset = self.class.parse_tzoffset(tzoff)
          raise ArgumentError.new("invalid timezone offset: #{tzoff}") if offset.nil?
        else
          raise ArgumentError.new("invalid timezone offset: #{tzoff}") if (tzoff < -720) || (tzoff > 720)
          offset = tzoff  
        end

        @hash[:TZOFFSET] = offset
        @hash.delete(:TZID)
      end

      # Get the date component, if any.
      #
      # @return [String] Returns the date component, if any.

      def date()
        if @hash
          @hash[:DATE]
        else
          nil
        end
      end

      # Set the date component.
      #
      # @param [String] date The date component; it must be a well formed DATE representation.
      #
      # @raise [ArgumentError] Raised if the date is not valid.
      # @raise [RuntimeError] Raised if the datetime is not valid.

      def date=(date)
        raise RuntimeError.new('the target datetime object is invalid') unless @hash
        raise ArgumentError.new("invalid date: #{date}") unless date =~ /^[0-9]{8}$/

        @hash[:DATE] = date
      end

      # Get the time component, if any.
      #
      # @return [String] Returns the time component (the time name), if any.

      def time()
        if @hash
          @hash[:TIME]
        else
          nil
        end
      end

      # Set the time component.
      #
      # @param [String] time The time component; it must be a well formed TIME representation.
      #
      # @raise [ArgumentError] Raised if the time is not valid.
      # @raise [RuntimeError] Raised if the datetime is not valid.

      def time=(time)
        raise RuntimeError.new('the target datetime object is invalid') unless @hash
        raise ArgumentError.new("invalid time: #{time}") unless time =~ /^[0-9]{4, 6}$/
        raise ArgumentError.new("invalid time: #{time}") if (time.length != 4) && (time.length != 6)

        @hash[:TIME] = time
      end

      # Get the type.
      #
      # @return [String] Returns one of {Fl::Core::Icalendar::DATETIME},
      #  {Fl::Core::Icalendar::DATE}, {Fl::Core::Icalendar::TIME},
      #  or {Fl::Core::Icalendar::NONE} (for an invalid datetime).

      def type()
        if !@hash
          Fl::Core::Icalendar::NONE
        elsif @hash.has_key?(:DATE)
          if @hash.has_key?(:TIME)
            Fl::Core::Icalendar::DATETIME
          else
            Fl::Core::Icalendar::DATE
          end
        elsif @hash.has_key?(:TIME)
          Fl::Core::Icalendar::TIME
        else
          Fl::Core::Icalendar::NONE
        end
      end

      # Convert the datetime to a string representation in RFC 5545 format.
      #
      # @return [String] Returns a string containing the datetime in RFC 5545 format.

      def to_rfc5545()
        return nil unless @hash

        dt = (@hash.has_key?(:DATE)) ? @hash[:DATE].dup : ''
        if @hash.has_key?(:TIME)
          dt << 'T' if dt.length > 0
          dt << @hash[:TIME]
          dt << '00' if @hash[:TIME].length == 4
        end

        if @hash.has_key?(:TZID)
          if (@hash[:TZID] == 'UTC') || (@hash[:TZID] == 'GMT')
            "#{dt}Z"
          else
            "TZID=#{@hash[:TZID]}:#{dt}"
          end
        else
          dt
        end
      end

      # Convert the datetime to a string representation in RFC 3339 format.
      #
      # @return [String] Returns a string containing the datetime in RFC 3339 format.
      #  If a timezone or timezone offset is defined, but this is DATE type, the timezone offset is
      #  not appended to the string representation.

      def to_rfc3339()
        return nil unless @hash

        dt = if @hash.has_key?(:DATE)
               d = @hash[:DATE]
               d[0, 4] + '-' + d[4, 2] + '-' + d[6, 2]
             else
               ''
             end

        if @hash.has_key?(:TIME)
          dt << 'T' if dt.length > 0
          t = @hash[:TIME]
          dt << t[0, 2] + ':' + t[2, 2]
          if t.length > 4
            dt << ':' + t[4, 2]
          else
            dt << ':00'
          end

          if @hash.has_key?(:TZOFFSET)
            dt << Fl::Core::Icalendar::Datetime.format_tzoffset(@hash[:TZOFFSET])
          elsif @hash.has_key?(:TZID)
            if (@hash[:TZID] == 'UTC') || (@hash[:TZID] == 'GMT')
              dt << 'Z'
            else
              tz = ActiveSupport::TimeZone.new(@hash[:TZID])
              dt << tz.formatted_offset if tz
            end
          end
        end

        dt
      end

      # Convert the datetime to a string representation.
      #
      # @return [String] Returns a string containing the datetime in RFC 5545 format.

      def to_s()
        to_rfc5545()
      end

      # Convert the datetime to a hash.
      #
      # @return [Hash] Returns a hash containing the three keys **:TZID**, **:DATE**, and **:TIME**
      #  (some may be missing). If it returns an empty hash, the datetime is not valid.

      def to_hash()
        if @hash
          @hash
        else
          {}
        end
      end

      # Get a Time object with the datetime values, but in the given timezone.
      # This is equivalent to setting the timezone in the object, and calling #to_time, but it
      # does not affect the object's state.
      #
      # @param [String, ActiveSupport::TimeZone] tz The timezone where to return the time.
      #  This is either a string containing the timezone name, or an ActiveSupport::TimeZone object.
      #
      # @return [ActiveSupport::TimeWithZone] Returns an ActiveSupport::TimeWithZone value that uses _tz_ as
      #  the timezone, and the object's date and time components.
      #  If :DATE is not present, the time uses the current date. If :TIME is not present, the time
      #  uses 000000 (midnight).
      #  Returns +nil+ if the object is not valid.

      def in_timezone(tz)
        return nil unless valid?

        tz = ActiveSupport::TimeZone.new(tz) if tz.is_a?(String)
        return nil if tz.nil?

        date = if @hash.has_key?(:DATE)
                 @hash[:DATE]
               else
                 n = tz.now
                 sprintf('%04d%02d%02d', n.year, n.month, n.day)
               end
        time = if @hash.has_key?(:TIME)
                 @hash[:TIME]
               else
                 '000000'
               end
        
        tz.parse(date + 'T' + time)
      end

      public

      # Convert a datetime into a Time (WithZone) object.
      #
      # @return [ActiveSupport::TimeWithZone] Returns a ActiveSupport::TimeWithZone object corresponding to
      #  the datetime values.
      #  If :TZID is not present, the time uses the local timezone. If :DATE is not present, the time
      #  uses the current date. If :TIME is not present, the time uses 000000 (midnight).
      #  Returns +nil+ if the datetime is not valid.

      def to_time()
        return nil unless valid?

        if @hash.has_key?(:TZID)
          in_timezone(@hash[:TZID])
        else
          in_timezone(Time.zone)
        end
      end

      # Convert a datetime to a timestamp.
      #
      # @return [Integer] Returns the timestamp for this datetime. Returns +nil+ if the datetime is not valid.

      def to_i()
        return nil unless valid?

        if @hash.has_key?(:TZID)
          in_timezone(ActiveSupport::TimeZone.new(@hash[:TZID])).to_i
        elsif @hash.has_key?(:TZOFFSET)
          in_timezone(ActiveSupport::TimeZone.new('UTC')).to_i - (@hash[:TZOFFSET] * 60)
        else
          in_timezone(Time.zone).to_i
        end
      end

      # The <=> operator.
      # Comparison is based on the datetime's timestamp.
      #
      # @param [Datetime] other The other datetime.
      #
      # @return Returns 

      def <=>(other)
        self.to_i <=> other.to_i
      end

      # Parse a timezone offset and convert to a numeric value.
      # This method parses an offset in the form `+/-HH:MM` or `+/-HHMM` and returns a number containing
      # the offset in minutes.
      #
      # @param [String] tzoff The timezone offset. The method accepts
      #  the offset value `Z` to indicate that the time is in UTC.
      #
      # @return Returns the offset in minutes, +nil+ if _tzoff_ is not a valid offset format.

      def self.parse_tzoffset(tzoff)
        return nil unless tzoff.is_a?(String)

        tzoff = tzoff.strip

        if tzoff.upcase == 'Z'
          return 0
        elsif tzoff =~ /^([-+])([0-9]{2}):([0-9]{2})$/
          m = Regexp.last_match
          plus_min = (m[1] == '-') ? -1 : 1
          return plus_min * ((m[2].to_i * 60) + m[3].to_i)
        elsif tzoff =~ /^([-+])([0-9]{2})([0-9]{2})$/
          m = Regexp.last_match
          plus_min = (m[1] == '-') ? -1 : 1
          return plus_min * ((m[2].to_i * 60) + m[3].to_i)
        else
          return nil
        end
      end

      # Parse an optional milliseconds component and timezone offset, and convert to numeric values.
      # This method checks if *tzoff* starts with a dot followed by digits. If so, it converts that to an integer
      # value after stripping the dot; the rest is passed to {.parse_tzoffset}.
      #
      # Otherwise, *tzoff* is passed to {.parse_tzoffset} directly.
      #
      # @param [String] tzoff The timezone offset, which may include a millisecond section.
      #
      # @return [Array] Returns a 2-element array containing the milliseconds component and the offset in minutes.
      #  If no millisecond component, `nil` is placed in the first element.
      # If *tzoff* does not contain a valid offset format, `nil` is placed in the second element.

      def self.parse_tzoffset_and_milliseconds(tzoff)
        return nil unless tzoff.is_a?(String)

        msec = nil
        tzoff = tzoff.strip

        if tzoff =~ /\.([0-9]+)(.*)/
          m = Regexp.last_match
          msec = m[1].to_i
          tzoff = m[2].strip
        end

        return [ msec, parse_tzoffset(tzoff) ]
      end

      # Format a timezone offset from a numeric value.
      # This method formats an offset in the form +/-HH:MM.
      #
      # @param [Number] tzoff The timezone offset, in minutes.
      #
      # @return [String] Returns the offset as a string with format +/-HH:MM, +nil+ if _tzoff_ is not in
      #  the range [-720, 720].

      def self.format_tzoffset(tzoff)
        return nil if (tzoff < -720) || (tzoff > 720)

        if tzoff == 0
          return '+00:00'
        elsif tzoff < 0
          atz = -tzoff
          fmt = '-%02d:%02d'
        else
          atz = tzoff
          fmt = '+%02d:%02d'
        end
          
        sprintf(fmt, (atz / 60).truncate, (atz % 60).truncate)
      end

      # Parse a string into its datetime components.
      #
      # @param [String] datetime A string containing a datetime in RFC 5545 or RFC 3339 format.
      #
      # @return [Hash] Returns a hash containing the keys **:TZOFFSET**, **:TZID**, **:DATE**, and **:TIME** (all keys
      #  are optional and present only if the corresponding component is in _datetime_).
      #  If _datetime_ does not contain a valid RFC 5545 or RFC 3339 representation, +nil+ is returned.
      #  The keys **:TZOFFSET** and **:TZID** are mutually exclusive.
      #  Components in RFC 3339 format are converted to RFC 5545 format.
      #
      # @note This method checks that the date and time components are well formed, but not that they
      #  are legal. Therefore, the date component 20141462 will be considered valid.

      def self.parse(datetime)
        hash = {}
        dt, tz = Fl::Core::Icalendar.split_datetime(datetime)
        hash[:TZID] = tz if tz

        if dt[4] == '-'
          # this is expected to be in RFC 3339 format, or 'YYY-MM-DD hh:mm:ss.xxx offset'
          # For RFC 3339, we pick up the milliseconds if present

          if dt =~ /^([-0-9]{10})T([:0-9]{5,8})(.*)/
            m = Regexp.last_match
            hash[:DATE] = m[1].gsub('-', '')
            hash[:TIME] = m[2].gsub(':', '')
            msec, tzoff = parse_tzoffset_and_milliseconds(m[3])
            hash[:MSEC] = msec unless msec.nil?
            unless tzoff.nil?
              hash[:TZOFFSET] = tzoff
              hash.delete(:TZID)
            end
          elsif dt =~ /^([-0-9]{10}) ([:0-9]{5,8})(.*)/
            m = Regexp.last_match
            hash[:DATE] = m[1].gsub('-', '')
            hash[:TIME] = m[2].gsub(':', '')
            msec, tzoff = parse_tzoffset_and_milliseconds(m[3])
            hash[:MSEC] = msec unless msec.nil?
            unless tzoff.nil?
              hash[:TZOFFSET] = tzoff
              hash.delete(:TZID)
            end
          elsif dt =~ /^([-0-9]{10})(.*)/
            m = Regexp.last_match
            hash[:DATE] = m[1].gsub('-', '')
            tzoff = parse_tzoffset(m[2])
            unless tzoff.nil?
              hash[:TZOFFSET] = tzoff
              hash.delete(:TZID)
            end
          elsif dt =~ /^[:0-9]{6,8}$/
            hash[:TIME] = dt.gsub(':', '')
          else
            return nil
          end
        else
          # this is expected to be in RFC 5545 format, which should not have a timezone offset,
          # but we are lenient and extract it anyway, in case someone has entered a date format
          # like '20160120T102030 -08:00'.

          if dt =~ /^([0-9]{8})T([0-9]{4,6})(.*)/
            m = Regexp.last_match
            hash[:DATE] = m[1]
            hash[:TIME] = m[2]
            tzoff = parse_tzoffset(m[3])
            unless tzoff.nil?
              hash[:TZOFFSET] = tzoff 
              hash.delete(:TZID)
            end
          elsif dt =~ /^([0-9]{8})(.*)/
            m = Regexp.last_match
            hash[:DATE] = m[1]
            tzoff = parse_tzoffset(m[2])
            unless tzoff.nil?
              hash[:TZOFFSET] = tzoff 
              hash.delete(:TZID)
            end
          elsif dt =~ /^[0-9]{4,6}$/
            hash[:TIME] = dt
          else
            return nil
          end
        end

        # we reject hashes that are not well formed, but we accept invalid ones.
        # Not sure this is what we should do...

        if self.well_formed?(hash)
          hash
        else
          nil
        end
      end
    end

    # Namespace for the Icalendar property hierarchy.

    module Property
      # Parse exception.

      class ParseError < RuntimeError
      end

      # A class to store the parsed representation of a property.
      # See the documentation for the {#to_hash} method for a description of the parsed representation.
      #
      # @note In general, this class is not meant to be used directly (although it certainly can be
      #  for generic properties). Rather, subclasses are defined that typically add property-specific
      #  behavior, usually in managing the value.

      class Base
        # Initializer.
        #
        # @param [String, Hash] data A string containing a property in RFC 5545 format, or a Hash containing
        #  a representation of the property.
        # @option data [String] :name The property name.
        # @option data [Hash] :params If present, a Hash containing parameter name/value pairs.
        # @option data [Object] :value An object (often a string) containing the value of the property.

        def initialize(data = nil)
          @hash = {
            :params => {}
          }

          if data.is_a?(String)
            @hash = Fl::Core::Icalendar::Property::Base.parse(data)
          elsif data.is_a?(Hash)
            @hash[:name] = data[:name].upcase if data.has_key?(:name)

            if data.has_key?(:params) && data[:params].is_a?(Hash)
              p = {}
              data[:params].each do |k, v|
                k1 = k.to_s.upcase.to_sym
                p[k1] = v.clone
              end
              @hash[:params] = p

              @hash[:type] = p[:VALUE].upcase if p.has_key?(:VALUE)
            end

            @hash[:value] = clone_value(data[:value]) if data.has_key?(:value)
          end
        end

        # Get the name.
        #
        # @return [String] Returns the name.

        def name
          @hash[:name]
        end

        # Set the name
        #
        # @param [String] n The new name; the value is converted to uppercase.

        def name=(n)
          @hash[:name] = n.upcase
        end

        # Check if a parameter exists.
        #
        # @param [String] name The parameter name.
        #
        # @return [Boolean] Returns +true+ if the parameter is defined, +false+ otherwise.

        def has_parameter?(name)
          k = name.to_s.upcase.to_sym
          @hash[:params].has_key?(k)
        end

        # Get a parameter value.
        #
        # @param [Symbol, String] name The parameter name.
        #
        # @return [Object] Returns the parameter value, +nil+ if no such parameter is defined.

        def get_parameter(name)
          k = name.to_s.upcase.to_sym
          @hash[:params][k]
        end

        # Set a parameter value.
        #
        # @param [Symbol, String] name The parameter name.
        # @param [Object] value The parameter value.

        def set_parameter(name, value)
          k = name.to_s.upcase.to_sym
          @hash[:params][k] = value

          if k == :VALUE
            @hash[:type] = value.upcase
          end
        end

        # Unset a parameter value.
        # Removes the parameter named _name_ from the list of parameters.
        #
        # @param [Symbol, String] name The parameter name.

        def unset_parameter(name)
          k = name.to_s.upcase.to_sym
          if @hash[:params].has_key?(k)
            @hash[:params].delete(k)
            if k == :VALUE
              @hash.delete(:type)
            end
          end
        end

        # Get the type.
        #
        # @return [String] Returns the value of the **:type** key in the parsed hash, if any.

        def type()
          @hash[:type]
        end

        # Set the type.
        # This also sets the **:VALUE** parameter.
        #
        # @param [String] t The new type; set to +nil+ to unset the type.

        def type=(t)
          if t
            @hash[:type] = t.upcase
            @hash[:params][:VALUE] = @hash[:type]
          else
            @hash.delete(:type)
            @hash[:params].delete(:VALUE)
          end
        end

        # Get the value.
        # The default implementation returns the current value, as stored literally in the 
        # **:value** hash entry. Subclasses may override to return subclass-specific forms of the value.
        #
        # @return [Object] Returns the property's value.

        def value()
          get_literal_value()
        end

        # Set the value.
        # Calls {#parse_value} and saves its return value in the **:value** hash entry.
        #
        # Since this method calls {#parse_value}, it is probably not necessary to override it.
        #
        # @param [Object] v The new value.

        def value=(v)
          set_literal_value(parse_value(v))
        end

        # Convert to a string.
        # Note that this method calls the protected method {#stringify_value}; subclasses can
        # override that method to build a string representation of the value as needed.
        #
        # @return [String] Returns the string representation of the property.

        def to_s()
          s = @hash[:name].clone
          @hash[:params].each do |k, v|
            s << ';' + k.to_s + '='
            if v.index(':') || v.index(';') || v.index(',')
              s << '"' + v + '"'
            else
              s << v
            end
          end
          s << ':'
          s << stringify_value(@hash[:value])

          s
        end

        # Convert to a Hash.
        # Not that the return value is a deep copy of the internal hash.
        #
        # @return [Hash] Returns a Hash containing the following keys:
        #
        #  - **:name** The property name.
        #  - **:params** A Hash containing parameter name/value pairs; empty if no parameters are defined.
        #  - **:type** If the **:VALUE** parameter is present in **:params**, this is its value.
        #  - **:value** An object (often a string) containing the value of the property. The base class
        #    stores the value as a string; subclasses may store it as a different object, after parsing it.

        def to_hash()
          rv = {}

          @hash.each do |k, v|
            case k
            when :value
              rv[k] = clone_value(v)

            else
              rv[k] = v.clone
            end
          end

          rv
        end

        # Parse a string containing an RFC 5545 property.
        #
        # @param [String] data A string containing a property in RFC 5545 format.
        #
        # @return [Hash] Returns a Hash containing the parsed representation of the property.
        #  The following keys are defined:
        #
        #  - **:name** The property name.
        #  - **:params** A Hash containing parameter name/value pairs; empty if no parameters are present.
        #  - **:value** A string containing the value of the property.

        def self.parse(data)
          acc = ''
          in_quote = false
          in_value = false
          in_escape = false
          rv = {
            :params => {}
          }

          data.split('').each do |cur|
            if cur == '"'
              if in_escape
                acc << cur
                in_escape = false
              elsif in_value
                acc << cur
              else
                in_quote = !in_quote
              end
            elsif cur == ':'
              if in_escape
                acc << cur
                in_escape = false
              elsif in_quote || in_value
                acc << cur
              elsif !rv.has_key?(:name)
                rv[:name] = acc.upcase
                acc = ''
                in_value = true
              else
                # this should be a parameter, since we already have a name

                idx = acc.index('=')
                raise ParseError.new("malformed RFC 5545 property: '#{data}'") unless idx
                kp = acc[0, idx].upcase.to_sym
                rv[:params][kp] = acc[idx+1, acc.length]
                acc = ''
                in_value = true
              end
            elsif cur == ';'
              if in_escape
                acc << cur
                in_escape = false
              elsif in_quote || in_value
                acc << cur
              elsif !rv.has_key?(:name)
                rv[:name] = acc.upcase
                acc = ''
              else
                # This is at least the second semicolon we have seen, so we have a parameter

                idx = acc.index('=')
                raise ParseError.new("malformed RFC 5545 property: '#{data}'") unless idx
                kp = acc[0, idx].upcase.to_sym
                rv[:params][kp] = acc[idx+1, acc.length]
                acc = ''
              end
            elsif cur == ','
              if in_escape
                acc << cur
                in_escape = false
              else
                acc << cur
              end
            elsif cur == '\\'
              if in_escape
                acc << cur
                in_escape = false
              else
                in_escape = true
              end
            elsif (cur == 'n') || (cur == 'N')
              if in_escape
                acc << "\n"
                in_escape = false
              else
                acc << cur
              end
            else
              acc << cur
            end
          end

          # whatever is left should be the value

          rv[:value] = parse_value(acc)

          # the :type is the :VALUE parameter, if present
          # and :VALUE is to be uppercased

          if rv[:params].has_key?(:VALUE)
            rv[:params][:VALUE].upcase!
            rv[:type] = rv[:params][:VALUE]
          end

          rv
        end

        # @!visibility private
        @@class_map = {}

        # Register +self+ with the class map.
        # This method is typically called in a class definition for subclasses of Property.
        #
        # @param [String] name The property name, for example: DTSTART, DTEND.

        def self.register_as(name)
          @@class_map[name.upcase] = self
        end

        # Factory of properties.
        #
        # @param [String] data A string containing a property in RFC 5545 format.
        #
        # @return [Fl::Core::Icalendar::Property::Base] If _data_ is parsed successfully, returns an
        #  instance of {Fl::Core::Icalendar::Property::Base} of the appropriate subclass (which
        #  will be {Fl::Core::Icalendar::Property::Base} if no subclasses
        #  are registered for the given property name). Otherwise, returns +nil+.

        def self.make_property(data)
          begin
            parsed = parse(data)

            name = parsed[:name]
            klass = @@class_map[name.upcase]
            if klass.nil?
              Base.new(parsed)
            else
              klass.new(parsed[:value], parsed[:params])
            end
          rescue ParseError => exc
            return nil
          rescue Exception => exc
            raise exc
          end
        end

        protected

        # Get the value literal.
        #
        # @return [Object] Returns the contents of the **:value** hash entry.

        def get_literal_value()
          @hash[:value]
        end

        # Set the value literal.
        # Sets the contents of the **:value** hash entry to _v_.
        #
        # @param [Object] v The new value.

        def set_literal_value(v)
          @hash[:value] = v
        end

        # Parse the value.
        # The default implementation simply returns _data_; subclasses may override to
        # provide specific parsing behavior.
        #
        # @param [Object] data The data to parse to obtain the value.
        #
        # @return [Object] Returns a parsed representation of _data_.

        def self.parse_value(data)
          data
        end

        # Parse the value.
        # The default implementation calls {.parse_value}; subclasses may override to
        # provide specific parsing behavior.
        #
        # @param [Object] data The data to parse to obtain the value.
        #
        # @return [Object] Returns a parsed representation of _data_.

        def parse_value(data)
          self.class.parse_value(data)
        end

        # Clone the value.
        # The default implementation simply clones the current value; subclasses may override to
        # provide specific cloning behavior.
        #
        # @param [Object] value The value to clone.
        #
        # @return [Object] Returns a clone of _value_.

        def clone_value(value)
          value.clone
        end

        # Build a string representation of the value.
        # The default implementation simply returns the value converted to a string via +to_s+.
        # Subclasses may override to provide specific stringification behavior.
        #
        # @param [Object] value The value to stringify.
        #
        # @return [String] Returns the string representation of _value_.

        def stringify_value(value)
          value.to_s
        end
      end

      # A class to store the SUMMARY property.

      class Summary < Base
        register_as 'SUMMARY'

        # Initializer.
        #
        # @param [String] value The string containing the summary (the property's value).
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(value, params = {})
          super({
                  :name => 'SUMMARY',
                  :params => params,
                  :value => value
                })
        end
      end

      # A class to store the LOCATION property.

      class Location < Base
        register_as 'LOCATION'

        # Initializer.
        #
        # @param [String] value The string containing the location (the property's value).
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(value, params = {})
          super({
                  :name => 'LOCATION',
                  :params => params,
                  :value => value
                })
        end
      end

      # A class to store the URL property.

      class Url < Base
        register_as 'URL'

        # Initializer.
        #
        # @param [String] value The string containing the url (the property's value).
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(value, params = {})
          super({
                  :name => 'URL',
                  :params => params,
                  :value => value
                })
        end
      end

      # A class to store the DESCRIPTION property.

      class Description < Base
        register_as 'DESCRIPTION'

        # Initializer.
        #
        # @param [String] value The string containing the description (the property's value).
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(value, params = {})
          super({
                  :name => 'DESCRIPTION',
                  :params => params,
                  :value => value
                })
        end
      end

      # A class to store a date-time property.
      # Instances store a single DATE-TIME, DATE, or TIME in the value.
      # If the +TZID+ parameter is present, it is stored separately in the +tzid+ attribute.

      class DateTime < Base
        # Initializer.
        #
        # If _datetime_ is a Time object, the initializer looks for the **:TZID** parameter
        # for possible conversion; if **:TZID** is not present, +UTC+ is assumed.
        # Also, it looks for the **:VALUE** parameter; if it is 'DATE-TIME', it stores the value as a DATE-TIME;
        # if 'DATE', as a DATE; and if 'TIME' as a TIME; any other value generates a DATE-TIME.
        #
        # @param [String] name The property name.
        # @param [String] datetime A string containing an RFC 5545 representation of the datetime;
        #  a DATE-TIME contains the full representation, a DATE just the DATE part, and a TIME the time part.
        #  Alternatively, a Time object containing the datetime; in this case, the object
        #  is converted to a string representation using the +TZID+ parameter in _params_
        #  if present, or UTC.
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(name, datetime, params = {})
          if params.has_key?(:TZID)
            @tzid = params.delete(:TZID)
          end

          super({
                  :name => name,
                  :params => params
                })

          self.value = datetime
        end

        # Get the timezone identifier for this property.
        # A +nil+ timezone identifier implies a floating datetime value.
        #
        # @return [String] Returns the value of the timezone identifier, +nil+ if not defined.

        def tzid()
          @tzid
        end

        # Set the timezone identifier for this property.
        # A +nil+ value for _tz_ implies a floating datetime value; in this case, all we do is set
        # the new value for tzid to +nil+.
        # If _tz_ is non-nil and the current timezone is +nil+, we simply set to the new timezone.
        # If _tz_ is non-nil and the current timezone is also non-nil, the current datetime is converted to
        # the new timezone.
        #
        # For example, say the property is in the America/Los_Angeles timezone, with a datetime
        # of 20140110T102030.
        # If we set the timezone to America/New_York, the new value is 20140110T132030.
        # If we set the timezone to +nil+, the new value is still 20140110T102030, but now we are in
        # floating time.
        #
        # @param [String] tz The new timezone identifier.

        def tzid=(tz)
          if tz
            if @tzid
              d = Fl::Core::Icalendar.parse(self.value)
              set_literal_value(format_value(d.in_time_zone(tz)))
            end
            @tzid = tz
          else
            @tzid = nil
          end
        end

        # Get the value as a Time object.
        #
        # @return [Time] Returns the value as a Time object, based on the current string value and timezone.

        def datetime()
          Fl::Core::Icalendar.parse(self.value)
        end

        # Get the value.
        # Overrides the default implementation to add the timezone identifier if present.
        #
        # @return [String] Returns the current value as a datetime.

        def value()
          stringify_value(super())
        end

        # Set the value.
        # Overrides the default implementation to convert the input value to a datetime.
        #
        # If _datetime_ is a Time object, the methods checks if the +tzid+ attribute is non-nil,
        # and uses it for timezone conversion; if +tzid+ is nil, +UTC+ is assumed.
        # Also, it looks for the **:VALUE** parameter; if it is 'DATE-TIME', it stores the value as a DATE-TIME;
        # if 'DATE', as a DATE; and if 'TIME' as a TIME; any other value generates a DATE-TIME.
        #
        # @param [String] datetime A string containing an RFC 5545 representation of the datetime;
        #  a DATE-TIME contains the full representation, a DATE just the DATE part, and a TIME the time part.
        #  Alternatively, a Time object containing the datetime; in this case, the object
        #  is converted to a string representation using the +tzid+ attribute and **:VALUE** parameter,
        #  if present.

        def value=(datetime)
          super(convert_datetime(datetime))
        end

        protected

        # Build a string representation of the value.
        # Overrides the default implementation to return the timezone identifier if present.
        #
        # @param [Object] value The value to stringify.
        #
        # @return [String] Returns the string representation of _value_.

        def stringify_value(value)
          Fl::Core::Icalendar.join_datetime(value.to_s, @tzid)
        end

        private

        def convert_datetime(datetime)
          if datetime.is_a?(Time)
            # a Time is converted to the current timezone if any; otherwise, to UTC

            tz = if @tzid
                   ActiveSupport::TimeZone.new(@tzid)
                 else
                   @tzid = 'UTC'
                   ActiveSupport::TimeZone.new('UTC')
                 end
            dt = format_value(datetime.in_time_zone(tz))

            # If the :VALUE is not specified, a Time object defalts it to DATE-TIME

            set_parameter(:VALUE, 'DATE-TIME') unless has_parameter?(:VALUE)
          else
            # If the string value contains TZID, we switch to that timezone.
            # Otherwise, we stay in the current timezone, which is either nil (floating time), or
            # some timezone

            dt, tzid = Fl::Core::Icalendar.split_datetime(datetime)

            type = Fl::Core::Icalendar.date_type(dt)
            if type == Fl::Core::Icalendar::NONE
              unset_parameter(:VALUE)
            else
              set_parameter(:VALUE, type)
            end

            if tzid
              # Since we have TZID, we switch timezone

              @tzid = tzid
            end
          end

          dt
        end

        def format_value(datetime)
          if has_parameter?(:VALUE)
            case get_parameter(:VALUE)
            when 'DATE-TIME'
              Fl::Core::Icalendar.format_datetime(datetime)
            when 'DATE'
              Fl::Core::Icalendar.format_date(datetime)
            when 'TIME'
              Fl::Core::Icalendar.format_time(datetime)
            else
              Fl::Core::Icalendar.format_datetime(datetime)
            end
          else
            Fl::Core::Icalendar.format_datetime(datetime)
          end
        end
      end

      # A class to store a DUE property.

      class Due < DateTime
        register_as 'DUE'

        # Initializer.
        # The name is set to +DUE+.
        #
        # @param [String, Time] datetime A string containing an RFC 5545 representation of the datetime, or
        #  a Time object.
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(datetime, params = {})
          super('DUE', datetime, params)
        end
      end

      # A class to store a DTSTART property.

      class Dtstart < DateTime
        register_as 'DTSTART'

        # Initializer.
        # The name is set to +DTSTART+.
        #
        # @param [String, Time] datetime A string containing an RFC 5545 representation of the datetime, or
        #  a Time object.
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(datetime, params = {})
          super('DTSTART', datetime, params)
        end
      end

      # A class to store a DTEND property.

      class Dtend < DateTime
        register_as 'DTEND'

        # Initializer.
        # The name is set to +DTEND+.
        #
        # @param [String, Time] datetime A string containing an RFC 5545 representation of the datetime, or
        #  a Time object.
        # @param [Hash] params A Hash containing parameters for the property.

        def initialize(datetime, params = {})
          super('DTEND', datetime, params)
        end
      end
    end
  end
end
