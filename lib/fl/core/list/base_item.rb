module Fl::Core::List
  # Base class for an item in a list.
  # Instances of this class manage the relationship between an object and its container list.
  # This creates a layer of indirection between a list and its contents that adds these properties
  # to the relationship:
  #
  # - An object can be placed in multiple lists.
  # - The relationship has an "owner" that may be different from the owner of the listed object.
  # - It is possible to associate a name with the listed object, and then use
  #   {Fl::Core::List::List#resolve_path} to find objects by name in a containment hierarchy.
  # - The relationship has a state, so that for example an item can be marked "selected."
  #   Note that, because an object can belong to multiple lists, its state may be different in two
  #   different lists.
  #
  # #### Custom list item classes
  #
  # Clients of the list API may want to extend the functionality of list item (and list) objects, for example
  # to add specialized attributes or behavior. In order to support that, the {Fl::Core::List::Base#item_factory}
  # method can be overridden to return the appropriate subclass of {BaseItem}.
  #
  # #### Associations
  #
  # The class defines the following associations:
  #
  # - {#owner} is a polymorphic `belongs_to` association linking to the entity that owns the list item
  #   (the creator). Note that this is a readonly value: once set in the constructor, the owner cannot be
  #   changed.
  # - {#list} is a `belongs_to` association linking to the container list (an instance of
  #   {Fl::Core::List::Base}).
  #   Note that this is a readonly value: once set in the constructor, the list cannot be changed.
  # - {#listed_object} is a polymorphic `belongs_to` association linking to the actual object in the item.
  #   Note that this is a readonly value: once set in the constructor, the listed object cannot be
  #   changed.
  # - {#state_updated_by} is a polymorphic `belongs_to` association linking to the entity that last
  #   modified the state of the item.
  
  class BaseItem < Fl::Core::ApplicationRecord
    include Fl::Core::ModelHash
    include Fl::Core::AttributeFilters
    extend Fl::Core::Query
    include Fl::Core::List::Helper
    
    self.table_name = 'fl_core_list_items'

    # @!visibility private
    StateByValue = {}
    # @!visibility private
    StateByName = {}

    # The name of the deselected state.
    STATE_SELECTED = :selected

    # The name of the selected state.
    STATE_DESELECTED = :deselected
    
    # @!attribute [r] list
    # A `belongs_to` association linking to the list to which the list item belongs.
    # This association is polymorphic because lists belong to a hierarchy rooted at {Fl::Core::List::Base}
    # @return [Association] the container list.
    
    belongs_to :list, class_name: 'Fl::Core::List::Base', foreign_key: 'list_id', optional: false

    # Sets the list object.
    # Wraps the {Fl::Core::List::Helper.list_from_parameter} method, using the parameter key **:list**.
    # Does not change the value of {#list} if the object is persisted.
    #
    # @param l [ActiveRecord::Base,String,GlobalID] The list; see {Fl::Core::List::Helper.list_from_parameter}
    #  for details.

    def list=(l)
      return if self.persisted?
      super(Fl::Core::List::Helper.list_from_parameter(l, :list))
    end

    # @!attribute [rw] listed_object
    # A polymorphic `belongs_to` association linking to the actual object in the list.
    # @return [Association] the listed object.

    belongs_to :listed_object, polymorphic: true, optional: false

    # Sets the listed object.
    # Wraps the {Fl::List::Helper.listable_from_parameter} method.
    # Does not change the value of {#listed_object} if the object is persisted.
    #
    # @param l [Hash,ActiveRecord::Base,String,GlobalID] The listed object; see
    #  {Fl::Core::List::Helper.listable_from_parameter} for details.
    # @param key [Symbol] The key to look up, if *l* is a Hash.

    def listed_object=(l, key = :listed_object)
      return if self.persisted?
      super(Fl::Core::List::Helper.listable_from_parameter(l, key))
    end

    # @!attribute [rw] listed_object_class_name
    # The class name of the listed object; this may differ from **:listed_object_type** under some
    # circumstances, for example if the listed object is part of a Single Table Inheritance hierarchy.
    # @return [String] the class name of the listed object.

    # @!attribute [rw] owner
    # The owner of the relationship; note that the owner could be different from the listed object's
    # owner.
    # @return [Association] the owner.
    
    belongs_to :owner, polymorphic: true, optional: true

    # Sets the owner.
    # Wraps the {Fl::Core::ParametersHelper.object_from_parameter} method, using the parameter key **:owner**.
    # Does not change the value of {#owner} if the object is persisted.
    #
    # @param o [ActiveRecord::Base,String,GlobalID] The owner; see {Fl::Core::ParametersHelper.object_from_parameter}
    #  for details.

    def owner=(o)
      return if self.persisted?
      super(Fl::Core::ParametersHelper.object_from_parameter(o, :owner))
    end
    
    # @!attribute [rw] name
    # The name of the item. This name can be used to identify items within a list, in particular
    # when resolving paths (see {List#resolve_path}).
    # It is case sensitive, must not contain `/` (forward slash) or `\` (backslash), must be at most
    # 200 characters long, and must be unique within the context of a list.
    # @return [String] the item's name (path component)

    # @!attribute [rw] state_locked
    # This attribute controls if the list item can be modified (by changing its state).
    # @return [Boolean] is `true` if the item's state is locked, `false` otherwise.
    
    # @!attribute [rw] state_updated_by
    # A polymorphic `belongs_to` association linking to the entity that last modified the item's state.
    # @return [Association] the updater.

    belongs_to :state_updated_by, polymorphic: true, optional: true

    # Sets the actor that last updated the state.
    # Wraps the {Fl::Core::ParametersHelper.object_from_parameter} method, using the parameter key
    # **:state_updated_by**.
    #
    # @param a [ActiveRecord::Base,String,GlobalID] The actor; see {Fl::Core::ParametersHelper.object_from_parameter}
    #  for details.

    def state_updated_by=(a)
      return super(Fl::Core::ParametersHelper.object_from_parameter(a, :state_updated_by))
    end

    # @!attribute [rw] state_note
    # The note associated with the last state change.
    # @return [String] the state note.

    validate :object_must_be_listable
    validate :check_duplicate_entries, :on => :create
    validate :validate_state
    validates :name, :length => { :maximum => 200 }
    validate :validate_name

    before_create :object_state_defaults_for_create, :set_class_name_field, :set_fingerprints
    after_create :update_list_timestamps
    after_destroy :check_list_item
    after_destroy :update_list_timestamps
    before_save :object_state_defaults_for_save
    before_save :refresh_item_summary
    after_save :bump_list_timestamp

    filtered_attribute :state_note, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.

    def initialize(attrs = {})
      rv = super(attrs)

      self.owner = self.list.owner if !self.owner && self.list

      self.state = Fl::Core::List::BaseItem::STATE_SELECTED unless self.state?
      self.state_updated_by = self.owner if self.state_updated_by.nil?
      self.state_locked = self.list.default_item_state_locked if self.list && !((self.state_locked == true) || (self.state_locked == false))

      if self.listed_object
        self.item_summary = self.listed_object.list_item_summary
        self.listed_object_created_at = self.listed_object.created_at
        self.listed_object_updated_at = self.listed_object.updated_at
      end
      
      # A newly created list object will cause the list update time to be bumped

      @bump_list_update_time = true

      rv
    end

    # Bulk updates.
    # Ignores the **:list**, **:listed_object**, and **:owner** attributes if persisted.
    #
    # @param attrs [Hash] The attributes.

    def update(attrs)
      a = attrs.reduce({ }) do |acc, kvp|
        k, v = kvp
        sk = k.to_sym
        case sk
        when :list, :listed_object, :owner
          acc[sk] = v unless persisted?
        else
          acc[sk] = v
        end

        acc
      end

      return super(a)
    end
    
    # The setter for the state.
    # This method sets the state to *state*, the state timestamp to the current time, and the state user
    # to the owner. Because of this behavior, clients should call {#set_state} instead, which
    # lets them specify a user.
    #
    # @param state The state: a symbol or an integer value.

    def state=(state)
      set_state(state, nil)
    end

    # The getter for the state.
    #
    # @return Returns a symbolic representation of the state.

    def state()
      Fl::Core::List::BaseItem.state_from_db(read_attribute(:state))
    end

    # Sets the state, by a given actor.
    #
    # @param state [Symbol,String,Integer] The state: a symbol or string, or an integer value.
    # @param actor The actor that should be marked as having set the state; if @c nil, the owner is used.

    def set_state(state, actor = nil)
      write_attribute(:state, Fl::Core::List::BaseItem.state_to_db(state))
      write_attribute(:state_updated_at, Time.new)

      self.state_updated_by = (actor.nil?) ? self.owner : actor

      # setting the state will cause the update time on the list to be bumped

      @bump_list_update_time = true
    end

    # Set the note associated with the state.
    #
    # @param note [String] A string containing the note.

    def state_note=(note)
      rv = super(note)

      # setting the state note will cause the update time on the list to be bumped

      @bump_list_update_time = true

      return rv
    end

    # @!visibility private
    QUERY_FILTERS_CONFIG = {
      filters: {
        lists: {
          type: :references,
          field: 'list_id',
          convert: :id
        },

        owners: {
          type: :polymorphic_references,
          field: 'owner_fingerprint',
          convert: :fingerprint
        },

        listables: {
          type: :polymorphic_references,
          field: 'listed_object_fingerprint',
          convert: :fingerprint
        },

        created: {
          type: :timestamp,
          field: 'created_at',
          convert: :timestamp
        },

        updated: {
          type: :timestamp,
          field: 'updated_at',
          convert: :timestamp
        },

        listable_created: {
          type: :timestamp,
          field: 'listed_object_created_at',
          convert: :timestamp
        },

        listable_updated: {
          type: :timestamp,
          field: 'listed_object_updated_at',
          convert: :timestamp
        }
      }
    }
  
    # Build a query to fetch list items.
    # The query supports getting list items for one or more (including all) lists.
    #
    # The **:filters** option contains a description of clauses to restrict the result set based on one or more
    # conditions. It is meant to be parsed by {Fl::Core::Query::Filter#generate} to construct a set of WHERE clauses
    # and associated bind parameters. The following filters are supported:
    #
    # - **:lists** is a **:polymorphic_references** filter that limits the returned values to those list items
    #   whose {#list} appears in the **:only** list, or does not appear in the **:except** list.
    #   The elements in the arrays are: instances of {Fl::Core::List::Base}; object identifiers; object fingerprints;
    #   or GlobalIDs.
    # - **:owners** is a **:polymorphic_references** filter that limits the returned values to those lists
    #   whose {#owner} appears in the **:only** list, or does not appear in the **:except** list.
    #   The elements in the arrays are: instances of {ActiveRecord::Base}; object fingerprints; or GlobalIDs.
    # - **:listables** is a **:polymorphic_references** filter that limits the returned values to those list itemss
    #   whose {#listable_object} appears in the **:only** list, or does not appear in the **:except** list.
    #   The elements in the arrays are: instances of {ActiveRecord::Base}; object fingerprints; or GlobalIDs.
    # - **:listable_created** is a **:timestamp** filter type that selects based on the **:listed_object_created_at**
    #   column. Therefore, it is used to select based on the listable's creation time.
    # - **:listable_updated** is a **:timestamp** filter type that selects based on the **:listed_object_updated_at**
    #   column. Therefore, it is used to select based on the listable's modification time.
    # - **:created** is a **:timestamp** filter type that selects based on the **:created_at** column.
    # - **:updated** is a **:timestamp** filter type that selects based on the **:updated_at** column.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #
    # @option opts [Hash] :filters A hash containing filter specifications; see the section on filters, above.
    # @option opts [Integer] :offset Sets the number of records to skip before returning;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to 0 (start at the beginning).
    # @option opts [Integer] :limit The maximum number of comments to return;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to all comments.
    # @option opts [String] :order A string containing the <tt>ORDER BY</tt> clause for the comments;
    #  a `nil` value causes the option to be ignored.
    #  Defaults to <tt>updated_at DESC</tt>, so that the comments are ordered by modification time, 
    #  with the most recent one listed first.
    # @option opts [Symbol, Array<Symbol>, Hash] :includes An array of symbols (or a single symbol),
    #  or a hash, to pass to the +includes+ method
    #  of the relation; see the guide on the ActiveRecord query interface about this method.
    #  The value is normalized via a call to {Fl::Core::Query::QueryHelper.adjust_includes}.
    #  The default value is `[ :owner, :list, :listed_object ]`; if you know that the owner contains
    #  an attachment attribute like `avatar`, a good value for this option is
    #  `[ { owner: [ :avatar ] }, :list, :listed_object ]`.
    # @option opts [String,Symbol,Array<String,Symbol>] :attachments The names of properties in **:includes**
    #  that contain ActiveStorage attachments; these properties are converted to a blob association by
    #  {Fl::Core::Query::QueryHelper.adjust_includes}. A scalar value is converted to a one element array.
    #  Defaults to `[ :avatar ]`.
    #
    # Note that *:limit*, *:offset*, *:order*, and *:includes* are convenience options, since they can be
    # added later by making calls to +limit+, +offset+, +order+, and +includes+ respectively, on the
    # return value. But there situations where the return type is hidden inside an API wrapper, and
    # the only way to trigger these calls is through the configuration options.
    #
    # @return [ActiveRecord::Relation] Returns an ActiveRecord relation mapping to a query in the database.

    def self.build_query(opts = {})
      q = self

      q = Fl::Core::Query::QueryHelper.add_includes(q, opts[:includes],
                                                    [ :owner, :list, :listed_object ], opts[:attachments])
      q = Fl::Core::Query::QueryHelper.add_filters(q, opts[:filters], QUERY_FILTERS_CONFIG)
      q = Fl::Core::Query::QueryHelper.add_order_clause(q, opts)
      q = Fl::Core::Query::QueryHelper.add_offset_clause(q, opts)
      q = Fl::Core::Query::QueryHelper.add_limit_clause(q, opts)

      return q
    end
  
    # Execute a query to fetch the number of list items for a given set of query options.
    # The number returned is subject to the configuration options +opts+; for example,
    # if <tt>opts[:only_lists]</tt> is defined, the return value is the number of list items whose
    # list identifiers are in the option.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {.build_query}.
    #
    # @return [Integer] Returns the number of list items that would be returned by the query.

    def self.count_list_items(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end
    
    # Generate a query for list items in a single list.
    # This can be accomplished via {.build_query} by passing an appropriate value for
    # the **lists:only:** filter, and it is implemented as such, but is provided as a separate
    # method for convenience.
    #
    # @param list [Fl::Core::List::Base, String, GlobalID] The list for which to get list items; the value
    #  is either an object, or a string containing the listable's fingerprint, or a GlobalID.
    # @param opts [Hash] Additional options for the query; these are merged with **:only_lists**
    #  and passed to {.build_query}.
    #
    # @return [ActiveRecord::Relation] Returns a relation.
    
    def self.query_for_list(list, opts = {})
      return build_query(merge_filters(opts, { order: 'sort_order ASC' }, { lists: { only: list } }))
    end
    
    # Generate a query for list items that contain a given listable.
    # This can be accomplished via {.build_query} by passing an appropriate value for
    # the **:listables:only** filter, and it is implemented as such, but is provided as a separate
    # method for convenience.
    #
    # Note that this method (indirectly) returns all lists where *listable* is defined; `map` the
    # returned value to generate an array of lists:
    #
    # ```
    # lists = Fl::Core::List::BaseItem.query_for_listable(listable).map { |li| li.list }
    # ```
    #
    # @param listable [Object, String, GlobalID] The listable object for which to get list items; the value is either
    #  an object, or a string containing the listable's fingerprint, or a GlobalID.
    # @param opts [Hash] Additional options for the query; these are merged with **:only_listables**
    #  and passed to {.build_query}.
    #
    # @return [ActiveRecord::Relation] Returns a relation.

    def self.query_for_listable(listable, opts = {})
      return build_query(merge_filters(opts, { order: 'updated_at DESC' }, { listables: { only: listable } }))
    end

    # Generate a query for the list item for a given listable in a given list.
    #
    # @param listable [Object, String, GlobalID] The listable object to look up; the method uses
    #  {Fl::Core::ParametersHelper.fingerprint_from_parameter} to extract the listable's fingerprint.
    # @param list [Fl::Core::List::Base, String, GlobalID] The list to search; the method uses
    #  {Fl::Core::ParametersHelper.fingerprint_from_parameter} to extract the listable's fingerprint and, from
    #  that, the list's object identifier.
    #
    # @return [ActiveRecord::Relation] Returns a relation; calling `first` on the return value should
    #  return the list item, or `nil` if *listable* is not in *list*.

    def self.query_for_listable_in_list(listable, list)
      lifp = Fl::Core::ParametersHelper.fingerprint_from_parameter(listable)
      lfp = Fl::Core::ParametersHelper.fingerprint_from_parameter(list)

      if !lifp.nil? && !lfp.nil?
        lid = split_fingerprint(lfp)[1]
        return self.where('(list_id = :lid) AND (listed_object_fingerprint = :lifp)', { lid: lid, lifp: lifp })
      else
        return self.none
      end
    end
          
    # Find a listable in a list.
    # This method wraps around {.query_for_listable_in_list}, calling `first` on its return value,
    # and then getting the **:listed_object** attribute.
    #
    # @param listable [Object, String, GlobalID] The listable object to look up; the method uses
    #  {Fl::Core::ParametersHelper.fingerprint_from_parameter} to extract the listable's fingerprint.
    # @param list [Fl::Core::List::Base, String, GlobalID] The list to search; the method uses
    #  {Fl::Core::ParametersHelper.fingerprint_from_parameter} to extract the listable's fingerprint and, from
    #  that, the list's object identifier.
    #
    # @return [Object] If *listable* is present in *list*, returns the listable; otherwise, returns `nil`.

    def self.find_listable_in_list(listable, list)
      li = query_for_listable_in_list(listable, list).first
      (li.nil?) ? nil : li.listed_object
    end

    # Refresh the denormalized **:item_summary** attribute for a given listed object.
    # This method runs an UPDATE SQL statement that sets the **:item_summary** column for all
    # records associated with the listed object *listable*.
    #
    # @param listable The listable object whose list item summary is to be placed in associated records
    #  of the list objects table.

    def self.refresh_item_summaries(listable)
      # Since we can't seem to be able to use bind variables, let's just sanitize the SQL
      # There *is* a way to use bind variable, but I'm not smart enough to figure it out...
      
      sql = "UPDATE #{table_name} SET "
      sql += sanitize_sql_for_assignment({
                                           item_summary: listable.list_item_summary,
                                           listed_object_created_at: listable.created_at,
                                           listed_object_updated_at: listable.updated_at
                                         })
      sql += ' WHERE ('
      sql += sanitize_sql_for_conditions([ '(listed_object_fingerprint = :fp)', fp: listable.fingerprint ])
      sql += ')'
      self.connection.exec_update(sql, "item_summary_update")
    end

    # Convert a state symbol to a value as stored in the database.
    #
    # @param state [Symbol,String,Numeric] The symbolic value of the state.
    #
    # @return [Integer,nil] Returns the converted value, `nil` if *state* is not a valid name
    #  (or a valid value).

    def self.state_to_db(state)
      return nil if state.nil?

      load_list_item_state_values()

      case state
      when Numeric
        state_i = state.to_i
        (StateByValue.has_key?(state_i)) ? state_i : nil
      else
        state_s = state.to_s
        if state_s =~ /^(\+|\-)?[0-9]+$/
          state_i = state_s.to_i
          (StateByValue.has_key?(state_i)) ? state_i : nil
        else
          state_y = state.to_sym
          (StateByName.has_key?(state_y)) ? StateByName[state_y] : nil
        end
      end
    end

    # Convert a state symbol from a value as stored in the database.
    #
    # @param state [Integer] The value for the state as stored in the database.
    #
    # @return [Symbol,nil] Returns the symbolic value of the state, or `nil` if *value* is `nil`.
    #
    # @raise Throws an exception if *value* is not in the database table.
      
    def self.state_from_db(state)
      return nil if state.nil?

      load_list_item_state_values()
        
      case state
      when Numeric
        state_i = state.to_i
        raise "bad state value: #{state} (#{StateByValue})" unless StateByValue.has_key?(state_i)
        StateByValue[state_i]
      else
        state_s = state.to_s
        if state_s =~ /^(\+|\-)?[0-9]+$/
          state_i = state_s.to_i
          raise "bad state value: #{state}" unless StateByValue.has_key?(state_i)
          StateByValue[state_i]
        else
          state_y = state.to_sym
          raise "bad state value: #{state}" unless StateByName.has_key?(state_y)
          state_y
        end
      end
    end

    # Resolve a list item.
    # This method converts *o* to a {Fl::Core::List::BaseItem} if necessary.
    # The object to resolve, *o*, can be one of the following:
    #
    # 1. Instances of {Fl::Core::List::BaseItem}, which are kept as-is.
    #    However, the method enforces that *o* is in list *list*.
    # 2. Subclasses of {ActiveRecord::Base} that respond to the `listable?` method and return `true`
    #    (and are, therefore, listable).
    #    If *owner* is `nil`, and the object responds to `owner`, and `owner` returns a non-nil value,
    #    use that value; otherwise, use `list.owner`.
    # 3. Strings containing an object fingerprint, which is used to find the object in storage.
    #    The resulting objects should be listable as described in the previous item.
    # 4. Strings containing the representation of a GlobalID, which is used to find the object in storage.
    #    The resulting objects should be listable as described in the previous item.
    # 5. A GlobalID, which is used to find the object in storage.
    #    The resulting objects should be listable as described in the previous item.
    # 6. Hashes that contain attributes for the instance of {Fl::Core::List::BaseItem} to create.
    #    These hashes contain at least the **:listed_object** attribute.
    #    The value of **:list** is ignored: it is overridden by *list*.
    #    The value of **:listed_object** can be an ActiveRecord model instance, a GlobalID, or a string containing
    #    the object's fingerprint or a representation of a GlobalID.
    #    If *owner* is `nil`, and the hash contains a non-nil **:owner**, use that value; otherwise,
    #    use `list.owner`.
    #    All other key/vaue pairs in the hash are passed down to the constructor: it is the caller's
    #    responsibility to ensure that the list item (sub)class supports them.
    #  
    # @param o The object to resolve. See above for details.
    # @param list [Fl::Core::List::Base,String,GlobalID] The list where the object should be placed.
    # @param owner The owner for the resolved object. See above for a discussion on how this value is used.
    #
    # @return [Fl::Core::List::BaseItem,String] Returns either an instance
    #  of {Fl::Core::List::BaseItem}, or a string containing an error message.

    def self.resolve_object(o, list, owner = nil)
      begin
        nl = Fl::Core::ParametersHelper.object_from_parameter(list, nil, Fl::Core::List::Base, false)
        return "internal error: failed to convert #{list} to a list object" if nl.nil?
      rescue Exception => exc
        return "internal error: #{exc.message}"
      end
      
      c_o = _convert_object(o)
      
      if c_o.is_a?(Fl::Core::List::BaseItem)
        if c_o.list.id != nl.id
          resolved = I18n.tx('fl.core.list_item.model.different_list', item: c_o.fingerprint,
                             item_list: c_o.list.fingerprint, list: nl.fingerprint)
        else
          resolved = c_o
        end
      elsif c_o.is_a?(ActiveRecord::Base)
        c_owner = if owner
                    owner
                  elsif (c_o.respond_to?(:owner) && c_o.owner)
                    c_o.owner
                  else
                    nl.owner
                  end
        resolved = nl.item_factory({
                                     list: nl,
                                     listed_object: c_o,
                                     owner: c_owner
                                   })
      elsif c_o.is_a?(Hash)
        n_o = (c_o.has_key?(:listed_object)) ? _convert_object(c_o[:listed_object]) : nil
        if n_o.is_a?(String)
          resolved = n_o
        else
          c_owner = if owner
                      owner
                    elsif !c_o[:owner].nil?
                      c_o[:owner]
                    elsif (n_o.respond_to?(:owner) && n_o.owner)
                      n_o.owner
                    else
                      nl.owner
                    end
          nh = c_o.reduce({
                            list: nl,
                            listed_object: n_o,
                            owner: c_owner,
                            name: c_o[:name]
                          }) do |acc, kvp|
            hk, hv = kvp
            acc[hk] = hv unless acc.has_key?(hk)
            acc
          end

          resolved = nl.item_factory(nh)
        end
      else
        resolved = c_o
      end

      resolved
    end

    # Normalizes an array containing a list of objects in a list.
    # This method enumerates the contents of *objects*, calling {.resolve_object}
    # for each element and adding it to the normalized array.
    # Various types of elements are acceptable in *objects*, as described in the
    # documentation for {.resolve_object}.
    #
    # If an element is a string or hash and the object resolution triggers an error, the error string
    # is placed in the normalized array at that position. Additionally, if the resolved object is not
    # listable, an error string is also placed in the normalized array at that position.
    #
    # @param [Array] objects The input array (or a single object, which will be converted to an
    #  input array).
    # @param list [Fl::Core::List::Base,String,GlobalID] The list for which to perform the normalization; this value
    #  is passed to {.resolve_object}.
    # @param owner The owner for any newly created list objects; this value is passed to {.resolve_object}.
    #
    # @return Returns a two-element array:
    #  - The count of objects whose conversion failed; this is the count of elements in the normalized
    #    array that are strings.
    #  - An array containing the normalized, converted object, or error messages (as a String object).

    def self.normalize_objects(objects, list, owner = nil)
      return [0, []] unless objects

      objects = [ objects ] unless objects.is_a?(Array)
      errcount = 0
      converted = objects.map do |o|
        r = resolve_object(o, list, owner)
        errcount += 1 if r.is_a?(String)
        r
      end

      [ errcount, converted ]
    end

    protected

    # @!visibility private
    # Validation check: the listed object must be listable.

    def object_must_be_listable()
      o = self.listed_object
      if o && (!o.respond_to?(:listable?) || !o.listable?)
        errors.add(:listed_object, I18n.tx('fl.core.list_item.model.not_listable', listed_object: o.to_s))
      end
    end

    # @!visibility private
    # validation check: the listed object must not already be in the list

    def check_duplicate_entries()
      if self.listed_object && self.list
        lo = Fl::Core::List::BaseItem.query_for_listable_in_list(self.listed_object, self.list).first
        if lo
          errors.add(:listed_object, I18n.tx('fl.core.list_item.model.already_in_list',
                                             :listed_object => self.listed_object.to_s, :list => self.list))
        end
      end
    end

    # @!visibility private

    def validate_state()
      if Fl::Core::List::BaseItem.state_to_db(read_attribute(:state)).nil?
        self.errors.add(:state, I18n.tx('fl.core.list_item.model.validate.invalid_state',
                                        :value => read_attribute(:state)))
      end
    end

    # @!visibility private

    def validate_name()
      unless self.name.blank?
        name = self.name

        # we accept pretty much any name, except that it may not contain / or \
        
        if !name.index('/').nil? || !name.index('\\').nil?
          self.errors.add(:name, I18n.tx('fl.core.list_item.model.validate.invalid_name', :name => name))
        else
          q = Fl::Core::List::BaseItem.where('(name = :name)', name: name)
          q = q.where('(list_id = :lid)', lid: self.list.id) if self.list
          q = q.where('(id != :lid)', lid: self.id) if self.persisted?
          qc = q.count
          if qc > 0
            self.errors.add(:name, I18n.tx('fl.core.list_item.model.validate.duplicate_name', :name => name))
          end
        end
      end
    end
    
    # @!visibility private
    MINIMAL_HASH_KEYS = [ :owner, :list, :listed_object, :state_locked, :state, :sort_order,
                          :item_summary, :listed_object_created_at, :listed_object_updated_at, :name ]
    # @!visibility private
    STANDARD_HASH_KEYS = [ :state_updated_at, :state_updated_by, :state_note ]
    # @!visibility private
    VERBOSE_HASH_KEYS = [ ]
    # @!visibility private
    DEFAULT_LIST_OPTS = { :verbosity => :minimal }
    # @!visibility private
    DEFAULT_LISTED_OBJECT_OPTS = { :verbosity => :standard }
    # @!visibility private
    DEFAULT_OWNER_OPTS = { :verbosity => :minimal }
    # @!visibility private
    DEFAULT_STATE_UPDATED_BY_OPTS = { :verbosity => :minimal }

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

    # Build a Hash representation of the session.
    # This method returns a Hash that contains key/value pairs that describe the session.
    #
    # @param actor [Object] The actor for which we are building the hash representation.
    #  See the documentation for {Fl::ModelHash::InstanceMethods#to_hash} and 
    #  {Fl::ModelHash::InstanceMethods#to_hash_local}.
    # @param keys [Array<Symbols>] The keys to return.
    # @param opts [Hash] Options for the method. In addition to the standard options:
    #
    #  - :to_hash[:list] A hash of options to pass to the list's `to_hash` method.
    #  - :to_hash[:listed_object] A hash of options to pass to the listed object's `to_hash` method.
    #  - :to_hash[:owner] A hash of options to pass to the owner's `to_hash` method.
    #  - :to_hash[:state_updated_by] A hash of options to pass to the `to_hash` method
    #    for **:state_updated_by**.
    #
    # @return [Hash] Returns a Hash containing the list item's representation.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {
      }
      sp = nil
      keys.each do |k|
        case k.to_sym
        when :list
          list_opts = to_hash_opts_with_defaults(to_hash_opts[:list], DEFAULT_LIST_OPTS)
          rv[:list] = self.list.to_hash(actor, list_opts)
        when :listed_object
          lo_opts = to_hash_opts_with_defaults(to_hash_opts[:listed_object], DEFAULT_LISTED_OBJECT_OPTS)
          rv[:listed_object] = self.listed_object.to_hash(actor, lo_opts)
        when :owner
          if self.owner
            o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], DEFAULT_OWNER_OPTS)
            rv[:owner] = self.owner.to_hash(actor, o_opts)
          else
            rv[:owner] = nil
          end
        when :state_updated_by
          if self.state_updated_by
            u_opts = to_hash_opts_with_defaults(to_hash_opts[:state_updated_by], DEFAULT_STATE_UPDATED_BY_OPTS)
            rv[:state_updated_by] = self.state_updated_by.to_hash(actor, u_opts)
          else
            rv[:state_updated_by] = nil
          end
        when :state_updated_at, :listed_object_created_at, :listed_object_updated_at
          rv[k] = to_hash_date(self.send(k))
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private

    def self._convert_object(o)
      converted = nil

      case o
      when Fl::Core::List::BaseItem
        converted = o
      when ActiveRecord::Base
        if o.respond_to?(:listable?) && o.listable?
          converted = o
        else
          converted = I18n.tx('fl.core.list_item.model.not_listable', :listed_object => o.fingerprint)
        end
      when String, GlobalID
        begin
          ofp = Fl::Core::ParametersHelper.fingerprint_from_parameter(o)
          n_o = self.find_by_fingerprint(ofp)
          if n_o.respond_to?(:listable?) && n_o.listable?
            converted = n_o
          else
            converted = I18n.tx('fl.core.list_item.model.not_listable', :listed_object => o)
          end
        rescue Exception => exc
          converted = exc.message
        end
      when Hash
        converted = o
      else
        converted = I18n.tx('fl.core.list_item.model.bad_listed_object', :listed_object => o.to_s)
      end

      return converted
    end

    def self.table_alias
      'lit'
    end

    def self.load_list_item_state_values()
      if StateByValue.count < 1
        self.connection.select_all('SELECT id, name, desc_backstop FROM fl_core_list_item_state_t').each() do |r|
          id = r['id'].to_i
          sym = r['name'].to_sym
          StateByValue[id] = sym
          StateByName[sym] = id
        end
      end
    end

    def object_state_defaults_for_create()
      self.state_updated_by = self.owner unless self.state_updated_by
    end

    def set_class_name_field()
      self.listed_object_class_name = self.listed_object.class.name
    end

    def set_fingerprints()
      self.listed_object_fingerprint = self.listed_object.fingerprint
      self.owner_fingerprint = self.owner.fingerprint if self.owner
#      self.list_fingerprint = self.list.fingerprint if self.list
    end

    def check_list_item()
      # if the listed object maps to a list item, we need to check how many list objects are
      # associated with the list item. If no more, we need to delete the list item as well.
      # Note that there should be 0 if this was the last list object previous to the delete
      # (we are here after the delete, which has removed the listed object from the list item's
      # containers in the database)

#      if self.listed_object.is_a?(Fl::Core::List::BaseItem)
#        list_item = self.listed_object
#        list_item.destroy if list_item.containers.count == 0
#      end
    end

    def update_list_timestamps()
      self.list.updated_at = Time.new
      self.list.save
    end

    def object_state_defaults_for_save()
      state = read_attribute(:state)
      if state.nil?
        write_attribute(:state, Fl::Core::List::BaseItem.state_to_db(STATE_SELECTED))
        write_attribute(:state_updated_at, Time.new)
      else
        write_attribute(:state, Fl::Core::List::BaseItem.state_to_db(state))
      end
    end

    def refresh_item_summary()
      self.item_summary = self.listed_object.list_item_summary
    end

    def bump_list_timestamp()
      if @bump_list_update_time
        self.list.updated_at = Time.now
        self.list.save

        # after a save, we turn off the bump flag; this is done so that an object that is created
        # with new, and then saved to persist, is marked as "no bump" in case it is kept around by
        # the client and further modified.

        @bump_list_update_time = false
      end
    end

    def self.merge_filters(opts, opts_init, override_filters)
      nf = (opts[:filters] || opts['filters'] || { }).merge(override_filters)
      no = opts.reduce(opts_init) do |acc, kvp|
        k, v = kvp
        sk = k.to_sym
        acc[sk] = v unless sk == :filters
        acc
      end

      no[:filters] = nf

      return no
    end
  end
end
