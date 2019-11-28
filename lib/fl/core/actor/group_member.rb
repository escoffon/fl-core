module Fl::Core::Actor
  # A member in an actor group.
  # Instances of this class manage the relationship between an actor and its container group.
  # This creates a layer of indirection between a group and its members that adds these properties
  # to the relationship:
  #
  # - An actor can be placed in multiple groups.
  #
  # #### Associations
  #
  # The class defines the following associations:
  #
  # - {#group} is a `belongs_to` association linking to the container group (an instance of
  #   {Fl::Core::Actor::Group}).
  #   Note that this is a readonly value: once set in the constructor, the group cannot be changed.
  # - {#actor} is a polymorphic `belongs_to` association linking to the member actor.
  #   Note that this is a readonly value: once set in the constructor, the actor cannot be
  #   changed.
  
  class GroupMember < Fl::Core::ApplicationRecord
    include Fl::Core::ModelHash
    include Fl::Core::AttributeFilters
    extend Fl::Core::Query
    include Fl::Core::Actor::Helper
    
    self.table_name = 'fl_core_actor_group_members'

    # @!attribute [r] group
    # A `belongs_to` association linking to the group to which the member belongs.
    # @return [Association] the container group.
    
    belongs_to :group, class_name: 'Fl::Core::Actor::Group', optional: false

    # @!attribute [r] actor
    # A polymorphic `belongs_to` association linking to the actor in the group.
    # @return [Association] the member acrot.

    belongs_to :actor, polymorphic: true, optional: false

    validate :member_must_be_actor
    validate :check_duplicate_entries, :on => :create

    before_create :set_fingerprints, :populate_title
    after_create :update_group_timestamps
    after_destroy :check_group_member
    after_destroy :update_group_timestamps
    after_save :bump_group_timestamp

    filtered_attribute :title, [ FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :note, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.

    def initialize(attrs = {})
      if attrs.is_a?(Hash)
        attrs[:group] = group_from_parameter(attrs[:group]) if attrs.has_key?(:group)
        attrs[:actor] = actor_from_parameter(attrs[:actor]) if attrs[:actor]
      end
      rv = super(attrs)

      # A newly created list object will cause the list update time to be bumped

      @_bump_group_update_time = true

      rv
    end

    # Update attributes.
    # The method removes **:group** and **:actor** from *attrs* before calling the
    # superclass implementation.
    #
    # @param attrs [Hash] The attributes.
    #
    # @return @returns the return value from the `super` call.

    def update(attrs)
      nattrs = attrs.reduce({}) do |acc, a|
        ak, av = a
        case ak
        when :group, :actor
        else
          acc[ak] = av
        end

        acc
      end

      super(nattrs)
    end

    # The setter for the group.
    # Does not change the value of {#group} if the object is persisted.
    #
    # @param g [Fl::Core::Actor::Group] The group.

    def group=(g)
      super(g) unless self.persisted?
    end

    # The setter for the actor.
    # Does not change the value of {#actor} if the object is persisted.
    #
    # @param a [ActiveRecord::Base] The actor.

    def actor=(a)
      super(a) unless self.persisted?
    end
  
    # Build a query to fetch group members.
    # The query supports getting group members for one or more (including all) groups.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Fl::Core::Actor::Group,Integer,String>, Fl::Core::Actor::Group, Integer, String] :only_groups Limit the returned values to group members whose `group` attribute is in the option's
    #  value (technically, whose `group_id` attribute is in the list of identifiers derived from the option's
    #  value).
    #  The elements in an array value are {Fl::Core::Actor::Group} instances, group identifiers, or
    #  object fingerprints (string values are interpreted as fingerprints or object identifier, depending
    #  on their contents).
    #  If this option is not present, all group members are selected.
    # @option opts [Array<Fl::Core::Actor::Group,Integer,String>, Fl::Core::Actor::Group, Integer, String] :except_groups Limit the returned values to group members whose `group` attribute is not in the option's
    #  value (technically, whose `group_id` attribute is not in the list of identifiers derived from the option's
    #  value).
    #  The elements in an array value are {Fl::Core::Actor::Group} instances, group identifiers, or
    #  object fingerprints (string values are interpreted as fingerprints or object identifier, depending
    #  on their contents).
    #  If this option is not present, all group members are selected.
    # @option opts [Array<Object,String>, Object, String] :except_actors Limit the returned values to group
    #  members whose `actor` attribute is not in the option's value
    #  (technically, whose `actor_id` and `actor_type` attribute pairs are not in the list
    #  derived from the option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `listed_object` association is polymorphic.
    #  If this option is not present, all group members are selected.
    # @option opts [Integer, Time, String] :updated_after selects list items updated after a given time.
    # @option opts [Integer, Time, String] :created_after selects list items created after a given time.
    # @option opts [Integer, Time, String] :updated_before selects list items updated before a given time.
    # @option opts [Integer, Time, String] :created_before selects list items created before a given time.
    # @option opts [Integer] :offset Sets the number of records to skip before fetching;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to 0 (start at the beginning).
    # @option opts [Integer] :limit The maximum number of records to return;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to all records.
    # @option opts [String, Array] :order A string or array containing the <tt>ORDER BY</tt> clauses
    #  for the records. The string value is converted to an array by splitting it at commas.
    #  A `false` value or an empty string or array causes the option to be ignored.
    #  Defaults to <tt>list_id ASC, sort_order ASC</tt>, so that the records are ordered by sort order
    #  and grouped by list.
    # @option opts [Symbol, Array<Symbol>, Hash] :includes An array of symbols (or a single symbol),
    #  or a hash, to pass to the +includes+ method
    #  of the relation; see the guide on the ActiveRecord query interface about this method.
    #  The value defaults to `[ :group, :actor ]`, so that by default the {#group} and {#actor}
    #  association are eager loaded; we do this because there is a high probability that the caller
    #  will attempt to access either or both objects after the query.
    #
    # Note that *:limit*, *:offset*, and *:includes* are convenience options, since they can be
    # added later by making calls to +limit+, +offset+, and +includes+ respectively, on the
    # return value. But there are situations where the return type is hidden inside an API wrapper, and
    # the only way to trigger these calls is through the configuration options.
    #
    # @return [ActiveRecord::Relation] If the query options are empty, the method returns `self`
    #  (and therefore the class object); if they are not empty, it returns an association relation.

    def self.build_query(opts = {})
      q = self

      if opts[:includes]
        i = (opts[:includes].is_a?(Array) || opts[:includes].is_a?(Hash)) ? opts[:includes] : [ opts[:includes] ]
        q = q.includes(i)
      else
        q = q.includes([ :group, :actor ])
      end

      g_lists = partition_lists_of_references(opts, 'groups', Fl::Core::Actor::Group)
      a_lists = partition_lists_of_polymorphic_references(opts, 'actors')

      # if :only_groups is nil, and :except_groups is also nil, the two options will create an empty set,
      # so we can short circuit here.
      # and similarly for :only_actors and :except_actors

      g_nil_o = g_lists.has_key?(:only_groups) && g_lists[:only_groups].nil?
      g_nil_x = g_lists.has_key?(:except_groups) && g_lists[:except_groups].nil?
      a_nil_o = a_lists.has_key?(:only_actors) && a_lists[:only_actors].nil?
      a_nil_x = a_lists.has_key?(:except_actors) && a_lists[:except_actors].nil?

      if g_nil_o && g_nil_x && a_nil_o && a_nil_x
        return q.where('(1 = 0)')
      end
    
      if g_lists[:only_groups].is_a?(Array)
        # If we have :only_groups, the :except_groups have already been eliminated, so all we need
        # is the only_groups

        q = q.where('(group_id IN (:ul))', { ul: g_lists[:only_groups] })
      elsif g_lists[:except_groups]
        # since only_groups is not present, we need to add the except_groups

        q = q.where('(group_id NOT IN (:ul))', { ul: g_lists[:except_groups] })
      end

      if a_lists[:only_actors].is_a?(Array)
        # If we have :only_actors, the :except_actors have already been eliminated, so all we need
        # is the only_actors

        q = q.where('(actor_fingerprint IN (:ul))', { ul: a_lists[:only_actors] })
      elsif a_lists[:except_actors]
        # since only_actors is not present, we need to add the except_actors

        q = q.where('(actor_fingerprint NOT IN (:ul))', { ul: a_lists[:except_actors] })
      end
      
      ts = _date_filter_timestamps(opts)
      wt = []
      wta = {}
      if ts[:c_after_ts]
        wt << '(created_at > :c_after_ts)'
        wta[:c_after_ts] = ts[:c_after_ts].to_time
      end
      if ts[:u_after_ts]
        wt << '(updated_at > :u_after_ts)'
        wta[:u_after_ts] = ts[:u_after_ts].to_time
      end
      if ts[:c_before_ts]
        wt << '(created_at < :c_before_ts)'
        wta[:c_before_ts] = ts[:c_before_ts].to_time
      end
      if ts[:u_before_ts]
        wt << '(updated_at < :u_before_ts)'
        wta[:u_before_ts] = ts[:u_before_ts].to_time
      end
      if wt.count > 0
        q = q.where(wt.join(' AND '), wta)
      end

      order_clauses = _parse_order_option(opts)
      q = q.order(order_clauses) if order_clauses.is_a?(Array)

      offset = (opts.has_key?(:offset)) ? opts[:offset] : nil
      q = q.offset(offset) if offset.is_a?(Integer) && (offset > 0)

      limit = (opts.has_key?(:limit)) ? opts[:limit] : nil
      q = q.limit(limit) if limit.is_a?(Integer) && (limit > 0)

      q
    end
  
    # Execute a query to fetch the number of group members for a given set of query options.
    # The number returned is subject to the configuration options +opts+; for example,
    # if <tt>opts[:only_groups]</tt> is defined, the return value is the number of group members whose
    # group identifiers are in the option.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {.build_query}.
    #
    # @return [Integer] Returns the number of group members that would be returned by the query.

    def self.count_group_members(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end
    
    # Generate a query for group members in a single group.
    # This can be accomplished via {.build_query} by passing an appropriate value for
    # the **:only_groups** option, and it is implemented as such, but is provided as a separate
    # method for convenience.
    #
    # Note that this method (indirectly) returns all actors where *group* is defined; `map` the
    # returned value to generate an array of actors:
    #
    # ```
    # actors = Fl::Core::Actor::Group.query_for_group(group).map { |gm| gm.actor }
    # ```
    #
    # @param group [Fl::Core::Actor::Group, String] The group for which to get members; the value
    #  is either an object, or a string containing the group's fingerprint.
    # @param opts [Hash] Additional options for the query; these are merged with **:only_groups**
    #  and passed to {.build_query}.
    #
    # @return [ActiveRecord::Relation] Returns a relation.

    def self.query_for_group(group, opts = {})
      build_query({ order: 'sort_order ASC' }.merge(opts).merge({ only_groups: group, except_groups: nil }))
    end
    
    # Generate a query for group members that contain a given actor.
    # This query returns the list of groups of which *actor* is a members.
    # This can be accomplished via {.build_query} by passing an appropriate value for
    # the **:only_actors** option, and it is implemented as such, but is provided as a separate
    # method for convenience.
    #
    # Note that this method (indirectly) returns all groups where *actor* is defined; `map` the
    # returned value to generate an array of groups:
    #
    # ```
    # groups = Fl::Core::Actor::Group.query_for_actor(actor).map { |gm| gm.group }
    # ```
    #
    # @param actor [Object, String] The actor for which to get group members; the value is either
    #  an object, or a string containing the actor's fingerprint.
    # @param opts [Hash] Additional options for the query; these are merged with **:only_actors**
    #  and passed to {.build_query}.
    #
    # @return [ActiveRecord::Relation] Returns a relation.

    def self.query_for_actor(actor, opts = {})
      build_query({ order: 'updated_at DESC' }.merge(opts).merge({ only_actors: actor, except_actors: nil }))
    end
          
    # Generate a query for the group member for a given actor in a given group.
    #
    # @param actor [Object, String] The actor to look up; a string value is assumed to be a fingerprint.
    # @param group [Fl::Core::Actor::Group, String] The group to search; a string value is assumed to be
    #  a fingerprint.
    #
    # @return [ActiveRecord::Relation] Returns a relation; calling `first` on the return value should
    #  return the group member, or `nil` if *actor* is not in *group*.

    def self.query_for_actor_in_group(actor, group)
      gid = (group.is_a?(String)) ? split_fingerprint(group)[1] : group.id
      afp = (actor.is_a?(String)) ? actor : actor.fingerprint
      
      self.where('(group_id = :gid) AND (actor_fingerprint = :afp)', { gid: gid, afp: afp })
    end
          
    # Find an actor in a group.
    # This method wraps around {.query_for_actor_in_group}, calling `first` on its return value,
    # and then getting the **:actor** attribute.
    #
    # @param actor [Object, String] The actor to look up; a string value is assumed to be a fingerprint.
    # @param group [Fl::Core::Actor::Group, String] The group to search; a string value is assumed to be
    #  a fingerprint.
    #
    # @return [Object] If *actor* is present in *group*, returns the actor; otherwise, returns `nil`.

    def self.find_actor_in_group(actor, group)
      gm = query_for_actor_in_group(actor, group).first
      (gm.nil?) ? nil : gm.actor
    end

    # Resolve a group member actor.
    # This method converts *o* to a {Fl::Core::Actor::GroupMember} if necessary.
    # The object to resolve, *o*, can be one of the following:
    #
    # 1. Instances of {Fl::Core::Actor::GroupMember], which are kept as-is.
    #    However, the method enforces that *o* is in group *group*.
    # 2. Subclasses of {ActiveRecord::Base} that respond to the `is_actor?` method and return `true`
    #    (and are, therefore, actors).
    # 3. Strings containing an object fingerprint, which is used to find the object in storage.
    #    The resulting objects should be an actor as described in the previous item.
    # 4. Hashes that contain attributes for the instance of {Fl::Core::Actor::GroupMember} to create.
    #    These hashes contain at least the **:actor** attribute.
    #    The value of **:group** is ignored: it is overridden by *group*.
    #    The value of **:actor** can be an ActiveRecord model instance or a string containing
    #    the object's fingerprint.
    #    All other key/vaue pairs in the hash are passed down to the constructor: it is the caller's
    #    responsibility to ensure that the group member (sub)class supports them.
    #  
    # @param o The object to resolve. See above for details.
    # @param group [Fl::Core::Actor::Group] The group where the object should be placed.
    #
    # @return [Fl::Core::Actor::GroupMember,String] Returns either an instance
    #  of {Fl::Core::Actor::GroupMember}, or a string containing an error message.

    def self.resolve_actor(o, group)
      c_o = _convert_object(o)
      
      if c_o.is_a?(Fl::Core::Actor::GroupMember)
        if c_o.group.id != group.id
          resolved = I18n.tx('fl.core.actor_group.model.different_group', item: c_o.fingerprint,
                             item_group: c_o.group.fingerprint, group: group.fingerprint)
        else
          resolved = c_o
        end
      elsif c_o.is_a?(ActiveRecord::Base)
        resolved = self.new({ group: group, actor: c_o })
      elsif c_o.is_a?(Hash)
        n_o = (c_o.has_key?(:actor)) ? _convert_object(c_o[:actor]) : nil
        if n_o.is_a?(String)
          resolved = n_o
        else
          nh = c_o.reduce({ group: group, actor: n_o }) do |acc, kvp|
            hk, hv = kvp
            acc[hk] = hv unless acc.has_key?(hk)
            acc
          end

          resolved = self.new(nh)
        end
      else
        resolved = c_o
      end

      resolved
    end

    # Normalizes an array containing a list of actors in a group.
    # This method enumerates the contents of *actors*, calling {.resolve_actor}
    # for each element and adding it to the normalized array.
    # Various types of elements are acceptable in *actors*, as described in the
    # documentation for {.resolve_actor}.
    #
    # If an element is a string or hash and the object resolution triggers an error, the error string
    # is placed in the normalized array at that position. Additionally, if the resolved object is not
    # an actor, an error string is also placed in the normalized array at that position.
    #
    # @param [Array] actors The input array (or a single actor, which will be converted to an
    #  input array).
    # @param group [Fl::Core::Actor::Group] The group for which to perform the normalization; this value
    #  is passed to {.resolve_actor}.
    #
    # @return Returns a two-element array:
    #  - The count of objects whose conversion failed; this is the count of elements in the normalized
    #    array that are strings.
    #  - An array containing the normalized, converted object, or error messages (as a String object).

    def self.normalize_actors(actors, group)
      return [0, []] unless actors

      actors = [ actors ] unless actors.is_a?(Array)
      errcount = 0
      converted = actors.map do |o|
        r = resolve_actor(o, group)
        errcount += 1 if r.is_a?(String)
        r
      end

      [ errcount, converted ]
    end

    protected

    # @!visibility private
    # Validation check: the {#actor} association must point to an actor.

    def member_must_be_actor()
      o = self.actor
      if o && (!o.respond_to?(:is_actor?) || !o.is_actor?)
        errors.add(:actor, I18n.tx('fl.core.actor_group_member.model.not_actor', actor: o.to_s))
      end
    end

    # @!visibility private
    # validation check: the actor must not already be in the list

    def check_duplicate_entries()
      if self.actor && self.group
        lo = Fl::Core::Actor::GroupMember.query_for_actor_in_group(self.actor, self.group).first
        if lo
          errors.add(:actor, I18n.tx('fl.core.actor_group_member.model.already_in_group',
                                             :actor => self.actor.to_s, :group => self.group.to_s))
        end
      end
    end
    
    # @!visibility private
    MINIMAL_HASH_KEYS = [ :group, :actor, :title, :note ]
    # @!visibility private
    STANDARD_HASH_KEYS = [ ]
    # @!visibility private
    VERBOSE_HASH_KEYS = [ ]
    # @!visibility private
    DEFAULT_GROUP_OPTS = { :verbosity => :minimal }
    # @!visibility private
    DEFAULT_ACTOR_OPTS = { :verbosity => :standard }

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash. No options are processed by this method.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity != :id) && (verbosity != :ignore)
        if verbosity == :minimal
          {
            :include => MINIMAL_HASH_KEYS
          }
        elsif verbosity == :standard
          {
            :include => MINIMAL_HASH_KEYS | STANDARD_HASH_KEYS
          }
        elsif (verbosity == :verbose) || (verbosity == :complete)
          {
            :include => MINIMAL_HASH_KEYS | STANDARD_HASH_KEYS | VERBOSE_HASH_KEYS
          }
        else
          {}
        end
      else
        {}
      end
    end

    # Build a Hash representation of the group member.
    # This method returns a Hash that contains key/value pairs that describe the group member.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    #  See the documentation for {Fl::ModelHash::InstanceMethods#to_hash} and 
    #  {Fl::ModelHash::InstanceMethods#to_hash_local}.
    # @param keys [Array<Symbols>] The keys to return.
    # @param opts [Hash] Options for the method. In addition to the standard options:
    #
    #  - :to_hash[:group] A hash of options to pass to the groups's `to_hash` method.
    #  - :to_hash[:actor] A hash of options to pass to the actor's `to_hash` method.
    #
    # @return [Hash] Returns a Hash containing the list item's representation.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {
      }
      sp = nil
      keys.each do |k|
        case k.to_sym
        when :group
          g_opts = to_hash_opts_with_defaults(to_hash_opts[:group], DEFAULT_GROUP_OPTS)
          rv[:group] = self.group.to_hash(actor, g_opts)
        when :actor
          a_opts = to_hash_opts_with_defaults(to_hash_opts[:actor], DEFAULT_ACTOR_OPTS)
          rv[:actor] = self.actor.to_hash(actor, a_opts)
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private

    def self._convert_object(o)
      case o
      when Fl::Core::Actor::GroupMember
        converted = o
      when ActiveRecord::Base
        if o.respond_to?(:is_actor?) && o.is_actor?
          converted = o
        else
          converted = I18n.tx('fl.core.actor_group_member.model.not_actor', :actor => o.fingerprint)
        end
      when String
        begin
          n_o = self.find_by_fingerprint(o)
          if n_o.respond_to?(:is_actor?) && n_o.is_actor?
            converted = n_o
          else
            converted = I18n.tx('fl.core.actor_group_member.model.not_actor', :actor => o)
          end
        rescue Exception => exc
          converted = exc.message
        end
      when Hash
        converted = o
      else
        converted = I18n.tx('fl.core.actor_group_member.model.bad_actor', :actor => o.to_s)
      end

      converted
    end

    def self.table_alias
      'agm'
    end

    def set_fingerprints()
      self.actor_fingerprint = self.actor.fingerprint
    end

    def populate_title()
      self.title = "#{self.group.name} - #{self.actor.group_member_title()}" if self.title.nil?
    end

    def check_group_member()
      # if the listed object maps to a list item, we need to check how many list objects are
      # associated with the list item. If no more, we need to delete the list item as well.
      # Note that there should be 0 if this was the last list object previous to the delete
      # (we are here after the delete, which has removed the listed object from the list item's
      # containers in the database)

#      if self.listed_object.is_a?(Fl::Core::List::ListItem)
#        list_item = self.listed_object
#        list_item.destroy if list_item.containers.count == 0
#      end
    end

    def update_group_timestamps()
      self.group.updated_at = Time.new
      self.group.save
    end

    def bump_group_timestamp()
      if @_bump_group_update_time
        update_group_timestamps

        # after a save, we turn off the bump flag; this is done so that an object that is created
        # with new, and then saved to persist, is marked as "no bump" in case it is kept around by
        # the client and further modified.

        @_bump_group_update_time = false
      end
    end
  end
end
