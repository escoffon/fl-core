module Fl::Core
  # Timezone management utilities.

  module TimeZone
    # @!visibility private
    TIME_ZONE_RE = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(.(\d+))?/.freeze

    # Default timezone format.
    TS_FORMAT = '%Y-%m-%d %H:%M:%S'.freeze

    # Converts a DB timestamp from UTC to the given timezone.
    # Note that most DB timestamps are automatically corrected by Rails, but under some conditions
    # that won't happens. For example, the resource find methods (in the resource subclasses) pick
    # up the :created_at and :updated_at attributes from a join with the resources table, and those
    # don't get converted: they are left as strings.
    #
    # @param [String] ts The timestamp to convert.
    # @param [Timezone] tz The timezone to which to convert. If nil, we use the current timezone (Time.zone).
    #
    # @return [ActiveSupport::TimeWithZone] Returns a ActiveSupport::TimeWithZone converted to the given 
    #  timezone.

    def convert_db_timestamp(ts, tz = nil)
      unless ts.to_s =~ TIME_ZONE_RE
        raise "internal error: malformed database timestamp: #{ts} (#{ts.class})"
      end

      data = Regexp.last_match
      Time.utc(data[1], data[2], data[3], data[4], data[5], data[6], data[8]).in_time_zone((tz) ? tz : Time.zone)
    end

    # Format a timestamp.
    #
    # @param [String] ts The timestamp to format.
    # @param [String] format The format to use. if nil, use the default in {TS_FORMAT}.
    #
    # @return [String] Returns a string containing the formatted timestamp.

    def format_timestamp(ts, format = nil)
      ts.strftime((format) ? format : TS_FORMAT)
    end

    # Given a Rails timezone name, return the corresponding TZInfo name.
    #
    # @param [String] tzname The Rails timezone name.
    #
    # @return [String] If _tzname_ is a key in the ActiveSupport::TimeZone::MAPPING constant, returns the
    #  corresponding value. Otherwise, returns _tzname_.

    def self.tzinfo_name(tzname)
      if ::ActiveSupport::TimeZone::MAPPING.has_key?(tzname)
        ::ActiveSupport::TimeZone::MAPPING[tzname]
      else
        tzname
      end
    end

    @@reverse_mapping = nil

    # Return the mapping from Rails name to TZInfo name.
    #
    # @return [Hash] Returns a Hash where keys are Rails names, and values TZInfo names.

    def self.mapping()
      ::ActiveSupport::TimeZone::MAPPING
    end

    # Return the reverse mapping from TZInfo name to Rails name.
    #
    # @return [Hash] Returns a Hash where keys are TZInfo names, and values Rails names.

    def self.reverse_mapping()
      unless @@reverse_mapping
        @@reverse_mapping = ::ActiveSupport::TimeZone::MAPPING.invert
      end

      @@reverse_mapping
    end

    # Given a TZInfo timezone name, return the corresponding Rails timezone name.
    #
    # @param [String] tzname The Rails timezone name.
    #
    # @return [String] Returns the corresponding Rails timezone name, or _tzname_ if not found.

    def self.rails_name(tzname)
      rmap = reverse_mapping()
      if rmap.has_key?(tzname)
        rmap[tzname]
      else
        tzname
      end
    end

    # Given a timezone name or object, return a string representation.
    #
    # @param [String, ActiveSupport::TimeZone] tzn The timezone; this is a string containing the timezone name,
    #  or an ActiveSupport::TimeZone object.
    #
    # @return [String] Returns the string representation for the timezone.

    def self.timezone_display_string(tzn)
      if tzn.is_a?(String)
        if self.mapping.has_key?(tzn)
          # This is a Rails name: we can get the Rails timezone directly

          ActiveSupport::TimeZone.new(tzn).to_s
        elsif self.reverse_mapping.has_key?(tzn)
          # this is a TZInfo name: we need to get the equivalent Rails timezone

          ActiveSupport::TimeZone.new(self.reverse_mapping[tzn]).to_s
        else
          # unknown timezone: return as is

          return tzn
        end
      elsif tzn.is_a?(::ActiveSupport::TimeZone)
        if self.mapping.has_key?(tzn.name)
          # This is a Rails name: we can get the string representation directly

          tzn.to_s
        elsif self.reverse_mapping.has_key?(tzn.name)
          # this is a TZInfo name: we need to get the equivalent Rails timezone

          ActiveSupport::TimeZone.new(self.reverse_mapping[tzn.name]).to_s
        else
          tzn.to_s
        end
      elsif tzn.nil?
        ''
      else
        tzn.to_s
      end
    end
  end
end
