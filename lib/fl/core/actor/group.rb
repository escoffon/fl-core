module Fl::Core::Actor
  # Model class for actor groups.
  # An actor group manages a collection of actor objects by managing a collection of group member objects.
  # Any subclass of {ActiveRecord::Base} that wants to be placed in actor groups must call the
  # {Fl::Core::Actor::Actor::ClassMacros#is_actor} macro:
  #
  # ```
  # class MyModel < ActiveRecord::Base
  #  is_actor
  # end
  # ```
  # (Note that only subclasses of {ActiveRecord::Base} can be actors.)
  #
  # Instances of {Group} manage collections of {Fl::Core::Actor::GroupMember} objects, which adds
  # a few properties to the relationship, as described in the documentation for
  # {Fl::Core::Actor::GroupMember}. This is essentially a `has_many_through` association, where the
  # "through" class contains additional information for the relationship.
  #
  # #### Associations
  #
  # The class defines the following associations:
  #
  # - {#owner} is a `belongs_to` association to the entity that "owns" the group.
  # - {#members} is a `has_many` association that lists all the members in the group.
  # - {#groups} is a `has_many` association that lists all the groups to which the group belongs.
  #   This association is actually created implicitly by the
  #   {Fl::Core::Actor::Actor::ClassMacros#is_actor} macro.

  class Group < Fl::Core::ApplicationRecord
    # Exception raised by groups when group member normalization fails.
    
    class NormalizationError < RuntimeError
      # Initializer.
      #
      # @param msg [String] An error message.
      # @param olist [Array] An arry that contains the list of objects that triggered the error.
      #  Any string elements are added to the error list.
      
      def initialize(msg = '', olist = [])
        super(msg)

        @errs = if olist
                  olist.reduce([]) do |acc, o|
                    acc << o if o.is_a?(String)
                    acc
                  end
                else
                  [ ]
                end
      end

      # The error list.
      #
      # @return [Array<String>] Returns an array containing the error messages from the normalization.
      
      def errors
        @errs
      end
    end

    include Fl::Core::ModelHash
    include Fl::Core::AttributeFilters
    include Fl::Core::TitleManagement
    extend Fl::Core::Query
    include Fl::Core::Actor::Actor
    include Fl::Core::Actor::Helper
    
    self.table_name = 'fl_core_actor_groups'
    
    # @!attribute [r] groups
    # Since a group is an actor, it can be a member of other groups; the `is_actor` macro automatically
    # creates an association named `groups` that lists all the groups to which it belongs.
    # @return [Association] a `has_many` associations to the groups where `self` is a member.
    
    is_actor

    # @!attribute [rw] owner
    # A `belongs_to` association that describes the entity that "owns" the group; this is typically
    # the creator. This association is polymorphic and it is optional (*i.e.* the owner can be `nil`).
    # @return [Association] the list owner.

    belongs_to :owner, polymorphic: true, optional: true
    
    # @!attribute [rw] members
    # A `has_many` association containing the members; this association is a collection of
    # {Fl::Core::Actor::GroupMember} instances.
    # @return [Association] the members.

    has_many :members, autosave: true, class_name: 'Fl::Core::Actor::GroupMember', dependent: :destroy

    validates :name, :length => { :minimum => 1, :maximum => 200 }
    validate :validate_unique_name
    validate :check_group_members

    before_destroy :abort_for_public_group
    before_create :set_fingerprints

    filtered_attribute :name, [ FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :note, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    # @!attribute [rw] name
    # The group name. Must be unique (in case insensitive comparison).
    # @return [String] the group name.

    # @!attribute [rw] note
    # The note about the group.
    # @return [String] the note.

    # The name of the public group.
    PUBLIC_GROUP_NAME = '$$public$$'

    private
    @_public_group = nil

    public
    
    # Get the public group.
    # The public group is a system group that is used mainly to provide a grantee for permissions on
    # an object. It has no explicit members, and cannot be deleted.
    #
    # @return [Group,nil] Return the instance of {Group} for the systemwide public group.

    def self.public_group()
      if @_public_group.nil?
        begin
          @_public_group = self.where('(name = :n)', n: PUBLIC_GROUP_NAME).first

          # This is more or less a hack to support testing: the test framework seems to use the schema.rb
          # file to prep the test database, which means that the public group may get wiped out.
          # And it appears that seeds.rb is not executed, so we can't put the group creation there, either

          if @_public_group.nil?
            @_public_group = Fl::Core::Actor::Group.create(name: Fl::Core::Actor::Group::PUBLIC_GROUP_NAME,
                                                           note: 'Public group')
          end
        rescue => x
          Rails.logger.warn("error getting the public group: #{x.message}")
          @_public_group = nil
        end
      end

      @_public_group
    end
    
    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    #  The :actors pseudoattribute contains a list of actors to place in the group (by wrapping them
    #  in a Fl::Core::Actor::GroupMember).

    def initialize(attrs = {})
      attrs = attrs || {}
      actors = attrs.delete(:actors)

      attrs[:owner] = actor_from_parameter(attrs[:owner]) if attrs.has_key?(:owner)
      
      unless attrs.has_key?(:note)
        attrs[:note] = I18n.localize_x(Time.now.to_date, :format => :actor_group_name)
      end

      rv = super(attrs)

      set_actors(actors) if actors

      rv
    end

    # Bulk update.
    #
    # @param attrs [Hash] The attributes, including the **:actors** pseudo-attribute.

    def update(attrs)
      actors = attrs.delete(:actors)

      rv = super(attrs)

      if actors
        set_actors(actors)
        rv = self.save()
      end

      rv
    end

    # Look up a member relationship in this group.
    # This method runs a query that searches for a relationship to *actor* in the list.
    # If no relationship is found, `nil` is returned.
    #
    # @param actor [Object, String] The actor to look up; a string value is assumed to be a fingerprint.
    #
    # @return [Fl::Core::Actor::GroupMember,nil] If *actor* is found in in one of `self`'s group
    #  members, that group member is returned. Otherwise, `nil` is returned.

    def find_group_member(actor)
      if actor.is_a?(String)
        cname, oid = self.class.split_fingerprint(actor)
      else
        cname = actor.class.name
        oid = actor.id
      end

      self.members.where('(actor_type = :cname) AND (actor_id = :oid)', {
                           cname: cname,
                           oid: oid
                         }).first
    end

    # Get the list of actors in the group.
    # This method wraps around the {#members} association and returns the actor objects, rather
    # than the relationship objects.
    #
    # @param reload [Boolean] Set to `true` to reload the {#members} association.
    #
    # @return [Array] Returns an array containing the actors in the group;
    #  maps over the array returned
    #  by the {#members} association, extracting their **actor** attribute.

    def actors(reload = false)
      self.members.reload if reload
      self.members.map { |gm| gm.actor }
    end

    # Add an actor to the group.
    #
    # @param actor [ActiveRecord::Base] The actor to add; if already in the group, the request is ignored.
    # @param title [String] The title to give to the group member; this is typically used by presentations.
    # @param note [String] The note to associate with the group member; this is typically used by
    #  presentations.
    #
    # @return Returns the instance of {Fl::Core::Actor::GroupMember} that stores the association
    #  between `self` and *actor*. If *actor* is already in the group, the existing group member is returned.

    def add_actor(actor, title = nil, note = nil)
      gm = find_group_member(actor)
      unless gm
        gm = self.members.build({
                                  group: self,
                                  actor: actor,
                                  title: (title.is_a?(String)) ? title : nil,
                                  note: (note.is_a?(String)) ? note : nil
                                })
      end

      gm
    end

    # Remove an actor from the group.
    #
    # @param actor [ActiveRecord::Base, String] The actor to remove; if not in the group, the request
    #  is ignored. A string value is assumed to be a fingerprint.

    def remove_actor(actor)
      gm = find_group_member(actor)
      self.members.delete(gm) if gm
    end
  
    # Build a query to fetch groups.
    #
    # Note that any WHERE clauses from *:updated_after*, *:created_after*, *:updated_before*,
    # and *:created_before* are concatenated using the AND operator. The values for these options are:
    # a UNIX timestamp; a Time object; a string containing a representation of the time (this string
    # is converted to a {Fl::Core::Icalendar::Datetime} internally).
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    # @option opts [Array<Object,String>, Object, String] :only_owners Limit the returned values to groups
    #  whose `owner` attribute is in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
    #  If this option is not present, all groups are selected.
    # @option opts [Array<Object,String>, Object, String] :except_owners Limit the returned values to groups
    #  whose `owner` attribute is not in the option's value
    #  (technically, whose `owner_id` and `owner_type` attribute pairs are not in the list derived from the
    #  option's value).
    #  The elements in an array value are object instances or object fingerprints; note that identifiers
    #  are not supported, because the `owner` association is polymorphic.
    #  If this option is not present, all groups are selected.
    # @option opts [Integer, Time, String] :updated_after selects list items updated after a given time.
    # @option opts [Integer, Time, String] :created_after selects list items created after a given time.
    # @option opts [Integer, Time, String] :updated_before selects list items updated before a given time.
    # @option opts [Integer, Time, String] :created_before selects list items created before a given time.
    # @option opts [Integer] :offset Sets the number of records to skip before fetching;
    #  a +nil+ value causes the option to be ignored.
    #  Defaults to 0 (start at the beginning).
    # @option opts [Integer] :limit The maximum number of records to return;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to all records.
    # @option opts [String, Array] :order A string or array containing the <tt>ORDER BY</tt> clauses
    #  for the records. The string value is converted to an array by splitting it at commas.
    #  A `false` value or an empty string or array causes the option to be ignored.
    # @option opts [Symbol, Array<Symbol>, Hash] :includes An array of symbols (or a single symbol),
    #  or a hash, to pass to the +includes+ method
    #  of the relation; see the guide on the ActiveRecord query interface about this method.
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
      end

      o_lists = partition_lists_of_polymorphic_references(opts, 'owners')

      # if :only_owners is nil, and :except_owners is also nil, the two options will create an empty set,
      # so we can short circuit here.

      o_nil_o = o_lists.has_key?(:only_owners) && o_lists[:only_owners].nil?
      o_nil_x = o_lists.has_key?(:except_owners) && o_lists[:except_owners].nil?

      if o_nil_o && o_nil_x
        return q.where('(1 = 0)')
      end

      if o_lists[:only_owners].is_a?(Array)
        # If we have :only_owners, the :except_owners have already been eliminated, so all we need
        # is the only_owners

        q = q.where('(owner_fingerprint IN (:ul))', { ul: o_lists[:only_owners] })
      elsif o_lists[:except_owners]
        # since only_owners is not present, we need to add the except_owners

        q = q.where('(owner_fingerprint NOT IN (:ul))', { ul: o_lists[:except_owners] })
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
  
    # Execute a query to fetch the number of groups for a given set of query options.
    # The number returned is subject to the configuration options *opts*; for example,
    # if <tt>opts[:only_owners]</tt> is defined, the return value is the number of groups whose
    # owners are in the option.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {.build_query}.
    #
    # @return [Integer] Returns the number of list items that would be returned by the query.

    def self.count_groups(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end

    # Build a query to find group members in this group.
    # This is a convenience method that returns an `ActiveRecord::Relation` on {GroupMember} with a
    # where clause that selects members belonging to `self`.
    #
    # @param opts [Hash] Additional options to pass to {GroupMember.build_query}; note that
    #  **:only_groups** and **:except_groups** are ignored if present, since the method adds its own
    #  values for them.
    #
    # @return [ActiveRecord::Relation] Returns a relation that can be used to fetch the group members.

    def query_group_members(opts = {})
      Fl::Core::Actor::GroupMember.build_query(opts.merge({ only_groups: [ self ], except_groups: nil}))
    end
    
    protected

    # The default properties to return from `to_hash`.
    DEFAULT_HASH_KEYS = [ :note, :name, :owner ]
    # The additional verbose properties to return from `to_hash`.
    VERBOSE_HASH_KEYS = [ :members, :groups ]

    # Given a verbosity level, return predefined hash options to use.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    # @param verbosity [Symbol] The verbosity level; see #to_hash.
    # @param opts [Hash] The options that were passed to #to_hash. No options are processed by this method.
    #
    # @return [Hash] Returns a hash containing default options for +verbosity+.

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity == :minimal) || (verbosity == :standard)
        {
          :include => DEFAULT_HASH_KEYS
        }
      elsif (verbosity == :verbose) || (verbosity == :complete)
        {
          :include => DEFAULT_HASH_KEYS | VERBOSE_HASH_KEYS
        }
      else
        {}
      end
    end

    # Build a Hash representation of the list.
    # This method returns a Hash that contains key/value pairs that describe the list.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    #  See the documentation for {Fl::Core::ModelHash::InstanceMethods#to_hash} and 
    #  {Fl::Core::ModelHash::InstanceMethods#to_hash_local}.
    # @param keys [Array<Symbols>] The keys to return.
    # @param opts [Hash] Options for the method. The listed options are in addition to the standard ones.
    #
    # @option opts [Hash] :to_hash[:members] Hash options for the elements in the **:members** key.
    #  The value is passed as the parameter to the `to_hash` call to the listed objects.
    #  Note that, to return objects in the hash, you have to place **:members** in the **:include** key.
    #
    # @return [Hash] Returns a Hash containing the list representation.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {}
      sp = nil
      keys.each do |k|
        case k
        when :groups
          g_opts = to_hash_opts_with_defaults(to_hash_opts[:groups], { verbosity: :minimal })
          rv[k] = self.groups.map do |l|
            l.to_hash(actor, g_opts)
          end
        when :actors
          a_opts = to_hash_opts_with_defaults(to_hash_opts[:actors], { verbosity: :id })
          rv[k] = self.actors.map do |obj|
            obj.to_hash(actor, a_opts)
          end
        when :owner
          if self.owner
            o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], { verbosity: :minimal })
            rv[k] = self.owner.to_hash(actor, o_opts)
          else
            rv[k] = nil
          end
        when :members
          m_opts = to_hash_opts_with_defaults(to_hash_opts[:members], { verbosity: :minimal })
          rv[k] = self.members.map do |obj|
            obj.to_hash(actor, m_opts)
          end
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private
        
    def set_actors(objs)
      errs, conv = Fl::Core::Actor::GroupMember.normalize_actors(objs, self)
      if errs > 0
        exc = NormalizationError.new(I18n.tx('fl.core.actor_group.model.normalization_failure'), conv)
        raise exc
      else
        self.members = conv
      end
    end

    def abort_for_public_group()
      pg = Fl::Core::Actor::Group.public_group
      if !pg.nil? && (self.id == pg.id)
        raise ActiveRecord::Rollback.new('you may not destroy the public group')
      end
    end
    
    def set_fingerprints()
      self.owner_fingerprint = self.owner.fingerprint if self.owner
    end

    def validate_unique_name
      if self.name && (self.name.length > 0)
        q = self.class.where('(lower(name) = :name)', name: self.name.downcase)
        if self.persisted?
          q = q.where('(id != :id)', id: self.id)
        end

        if q.count > 0
          errors.add(:name, I18n.tx('fl.core.actor_group.model.duplicate_name', name: self.name))
        end
      end
    end
    
    def check_group_members
      self.members.each_with_index do |gm, idx|
        if !gm.actor.respond_to?(:is_actor?) || !gm.actor.is_actor?
          errors.add(:members, I18n.tx('fl.core.actor_group_member.model.not_actor',
                                       actor: gm.actor.fingerprint))
        elsif self.persisted? && !gm.group.id.nil? && (gm.group.id != self.id)
          errors.add(:members, I18n.tx('fl.core.actor_group.model.validate.inconsistent_group',
                                       group_member: gm.fingerprint, group: self.fingerprint))
        end
      end
    end
  end
end
