module Fl::Core::List
  # Base class for lists.
  # A list manages a collection of listable objects by managing a collection of list item objects.
  # Any subclass of {ActiveRecord::Base} that wants to be placed in lists must call the
  # {Fl::Core::List::Listable.is_listable} macro:
  #
  # ```
  # class MyModel < ActiveRecord::Base
  #   include Fl::Core::List::Listable
  #
  #   is_listable
  # end
  # ```
  # (Note that only subclasses of {ActiveRecord::Base} can be listable.)
  #
  # Instances of {List} manage collections of {Fl::Core::List::BaseItem} objects, which adds
  # a few properties to the relationship, as described in the documentation for
  # {Fl::Core::List::BaseItem}. This is essentially a `has_many_through` association, where the
  # "through" class contains additional information for the relationship.
  #
  # Note that the table for {List} objects includes a `type` column to trigger Single Table Inheritance:
  # subclasses can extend the list functionality by adding fields to the table.
  #
  # #### Custom list item classes
  #
  # Clients of the list API may want to extend the functionality of list item (and list) objects, for example
  # to add specialized attributes or behavior. In order to support that, the class defines the {#item_factory}
  # method to instantiate subclasses of {BaseItem} through a call to {#instantiate_list_item}.
  # The default implementation of {#instantiate_list_item} returns instances of
  # {Fl::Core::List::Item}, but subclasses of {List} can override it to return instances of a different
  # subclass of {Fl::Core::List::BaseItem}.
  #
  # #### Associations
  #
  # The class defines the following associations:
  #
  # - {#owner} is a `belongs_to` association to the entity that "owns" the list.
  # - {#list_items} is a `has_many` association that lists all the items in the list.
  # - {#containers} is a `has_many` association that lists all the containers (lists) to which the
  #   list belongs. (List objects are listables, so that nested lists are supported.)

  class Base < Fl::Core::ApplicationRecord
    # Exception raised by lists when listed object normalization fails.
    
    class NormalizationError < RuntimeError
      # Initializer.
      #
      # @param msg [String] An error message.
      # @param olist [Array] An array that contains the list of objects that triggered the error.
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
    include Fl::Core::List::Listable
    include Fl::Core::List::Helper
    
    self.table_name = 'fl_core_lists'
    
    # @!attribute [r] containers
    # Since a list can be placed in other lists, it automatically creates an association named `containers`
    # that lists all the lists to which it belongs.
    # @return [Association] a `has_many` associations to the list items where `self` is the
    #  listed object.
    #  Note that this associaition returns {Fl::Core::List::BaseItem} instances; to get the
    #  list objects, access their **:list** attribute. For example:
    #
    #  ```
    #    list = get_the_list()
    #    list_containers = list.containers.map { |li| li.list }
    #  ```
    
    is_listable

    # @!attribute [rw] owner
    # A `belongs_to` association that describes the entity that "owns" the list; this is typically
    # the creator. This association is polymorphic and it is optional (*i.e.* the owner can be `nil`).
    # @return [Association] the list owner.

    belongs_to :owner, polymorphic: true, optional: true

    # Sets the owner.
    # The method converts *o* to an object via a call to {Fl::Core::ParametersHelper.object_from_parameter}.
    #
    # @param o [ActiveRecord::Base,String,GlobalID] The owner object; see
    #  {Fl::Core::ParametersHelper.object_from_parameter} for details.

    def owner=(o)
      super(Fl::Core::ParametersHelper.object_from_parameter(o))
    end
    
    # @!attribute [rw] list_items
    # A `has_many` association containing the list items; this association is a collection of
    # {Fl::Core::List::BaseItem} instances.
    # @return [Association] the list items.

    has_many :list_items, -> { order("sort_order ASC") }, class_name: 'Fl::Core::List::BaseItem',
             autosave: true, dependent: :destroy, foreign_key: 'list_id'

    # @!attribute [rw] list_display_preferences
    # The display preferences for the list. This is a hash of options for use by presentations
    # to determine how the list should be displayed.
    # The contents of this hash are somewhat client-dependent, but some "standard" properties are:
    #
    # - **limit** An integer containing the number of items to display; the value -1 indicates all.
    # - **only_types** An array of class names listing the types of objects to display.
    # - **order** The sort order for the list.
    # - **only_states** An array containing the list of states to select.
    #
    # @return [Hash] The list display preferences; since this attribute is stored as JSON, the
    #  keys are strings and not symbols.

    serialize :list_display_preferences, JSON

    # The cutoff value for the title length when extracted from the caption.
    TITLE_LENGTH = 60

    validates :title, :length => { :minimum => 1, :maximum => 200 }
    # validates :list_access_level, :presence => true
    validates :default_item_state_locked, inclusion: { in: [ true, false ] }
    validate :check_list_items

    before_create :set_fingerprints
    before_validation :before_validation_checks
    before_save :before_save_checks

    filtered_attribute :title, [ FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :caption_html, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    # @!attribute [rw] title
    # The list title.
    # @return [String] the list title.

    # @!attribute [rw] caption_html
    # The list caption's HTML representation.
    # @return [String] the list caption.

    # @!attribute [rw] caption_json
    # The list caption's JSON representation. This is the master representation for the caption; {#caption_html}
    # has to be kept in sync with it.
    # @return [String] the list caption.

    serialize :caption_json, JSON
    
    # Constructor.
    #
    # @param attrs [Hash] A hash of initialization parameters.
    #  The :objects pseudoattribute contains a list of objects to place in the list (by wrapping them
    #  in a Fl::Core::List::BaseItem); these instances of Fl::Core::List::BaseItem use the
    #  list's owner as their owner.

    def initialize(attrs = {})
      attrs = attrs || {}
      objs = attrs.delete(:objects)

      unless attrs.has_key?(:caption_html) && attrs.has_key?(:caption_json)
        c = Fl::Core::ProseMirror::Helper.content(I18n.localize_x(Time.now.to_date, :format => :list_title))
        attrs[:caption_html] = c[:html]
        attrs[:caption_json] = c[:json]
      end

      attrs[:default_item_state_locked] = true unless attrs.has_key?(:default_item_state_locked)
      
      rv = super(attrs)

      if objs
        set_objects(objs, self.owner)
      end

      rv
    end

    # Bulk update.
    #
    # @param attrs [Hash] The attributes, including the **:objects** pseudo-attribute.

    def update(attrs)
      objs = attrs.delete(:objects)

      rv = super(attrs)

      if objs
        set_objects(objs, self.owner)
        rv = self.save()
      end

      rv
    end

    # Factory method for list items.
    # The default implementation returns an unpersisted instance of {Fl::Core::List::Item}; subclasses may
    # override the protected method {#instantiate_list_item} to return custom subclasses of {Fl::Core::List::BaseItem}.
    #
    # @param attrs [Hash] A hash of attributes to pass to the initializer. Note that the method uses the value
    #  of `self` if **:list** is not present in *attrs*; this is the recommended way of using the method.
    #
    # @return [BaseItem] Returns an instance of an appropriate subclassd of {BaseItem}.
    #  Note that the returned object has not yet been persisted (saved to the database); it is the caller's
    #  responsibility to do so.

    def item_factory(attrs)
      a = { list: self }.merge(attrs)
      return instantiate_list_item(a)
    end

    protected

    # Instantiate list items.
    # The default implementation returns an unpersisted instance of {Fl::Core::List::Item}; subclasses may
    # override it to return custom subclasses of {Fl::Core::List::BaseItem}.
    #
    # @param attrs [Hash] A hash of attributes to pass to the initializer.
    #
    # @return [BaseItem] Returns an instance of an appropriate subclassd of {BaseItem}.
    #  Note that the returned object has not yet been persisted (saved to the database); it is the caller's
    #  responsibility to do so.

    def instantiate_list_item(attrs)
      return Fl::Core::List::Item.new(attrs)
    end

    public
    
    # Look up an object relationship in this list.
    # This method runs a query that searches for a relationship to *obj* in the list.
    # If no relationship is found, `nil` is returned.
    #
    # @param obj [Object, String] The object to look up; a string value is assumed to be a fingerprint.
    #
    # @return [Fl::Core::List::BaseItem,nil] If *obj* is found in in one of `self`'s list items,
    #  that list item is returned. Otherwise, `nil` is returned.

    def find_list_item(obj)
      if obj.is_a?(String)
        cname, oid = self.class.split_fingerprint(obj)
      else
        cname = obj.class.name
        oid = obj.id
      end

      self.list_items.where('(listed_object_type = :cname) AND (listed_object_id = :oid)', {
                              cname: cname,
                              oid: oid
                            }).first
    end

    # Get the list of objects in the list.
    # This method wraps around the {#list_items} association and returns the listed objects, rather
    # than the relationship objects.
    #
    # @param reload [Boolean] Set to `true` to reload the {#list_items} association.
    #
    # @return [Array] Returns an array containing the objects in the list;
    #  maps over the array returned
    #  by the {#list_items} association, extracting their **list_object** attribute.

    def objects(reload = false)
      self.list_items.reload if reload
      self.list_items.map { |li| li.listed_object }
    end

    # Add an object to the list.
    #
    # @param obj [ActiveRecord::Base] The object to add; if already in the list, the request is ignored.
    # @param owner The owner for the list object that stores the association between `self` and *obj*.
    #  If `nil`, the list's owner is used.
    # @param name [String] The name to give to the list item; this is used by {#resolve_path} to find
    #  list items in a hierarchy.
    #
    # @return Returns the instance of {Fl::Core::List::BaseItem} that stores the association between
    #  `self` and *obj*. If *obj* is already in the list, the existing list item is returned.

    def add_object(obj, owner = nil, name = nil)
      li = find_list_item(obj)
      unless li
        li = item_factory({
                            list: self,
                            listed_object: obj,
                            owner: (owner) ? owner : self.owner,
                            name: (name.is_a?(String)) ? name : nil
                          })
        self.list_items << li
      end

      return li
    end

    # Remove an object from the list.
    #
    # @param obj [ActiveRecord::Base, String] The object to remove; if not in the list, the request
    #  is ignored. A string value is assumed to be a fingerprint.

    def remove_object(obj)
      li = find_list_item(obj)
      self.list_items.delete(li) if li
    end

    # Get the value of the next sort order in the sequence.
    # This method runs a query to fetch the highest value of the **sort_order** column in the
    # list items table (for this list), and returns that value plus 1.
    #
    # @return Returns the next value to use in **sort_order**.

    def next_sort_order()
      sql = "SELECT MAX(sort_order) as max_sort_order FROM #{Fl::Core::List::BaseItem.table_name} WHERE (list_id = #{self.id})"
      rec = self.class.connection.select_all(sql).first
      if rec['max_sort_order'].nil?
        1
      else
        rec['max_sort_order'].to_i + 1
      end
    end

    # @!visibility private
    QUERY_FILTERS_CONFIG = {
      filters: {
        owners: {
          type: :polymorphic_references,
          field: 'owner_fingerprint',
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
        }
      }
    }
  
    # Build a query to fetch lists.
    #
    # The **:filters** option contains a description of clauses to restrict the result set based on one or more
    # conditions. It is meant to be parsed by {Fl::Core::Query::Filter#generate} to construct a set of WHERE clauses
    # and associated bind parameters. The following filters are supported:
    #
    # - **:owners** is a **:polymorphic_references** filter that limits the returned values to those lists
    #   whose {#owner} appears in the **:only** list, or does not appear in the **:except** list.
    #   The elements in the arrays are: instances of {ActiveRecord::Base}; object fingerprints; or GlobalIDs.
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
    #  The default value is `[ :owner ]`; if you know that the owner contains
    #  an attachment attribute like `avatar`, a good value for this option is
    #  `[ { owner: [ :avatar ] } ]`.
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

      q = Fl::Core::Query::QueryHelper.add_includes(q, opts[:includes], [ :owner ], opts[:attachments])
      q = Fl::Core::Query::QueryHelper.add_filters(q, opts[:filters], QUERY_FILTERS_CONFIG)
      q = Fl::Core::Query::QueryHelper.add_order_clause(q, opts)
      q = Fl::Core::Query::QueryHelper.add_offset_clause(q, opts)
      q = Fl::Core::Query::QueryHelper.add_limit_clause(q, opts)

      return q
    end
  
    # Execute a query to fetch the number of lists for a given set of query options.
    # The number returned is subject to the configuration options *opts*; for example,
    # if <tt>opts[:only_owner]</tt> is defined, the return value is the number of lists whose
    # owners are in the option.
    #
    # @param opts [Hash] A Hash containing configuration options for the query.
    #  See the documentation for {.build_query}.
    #
    # @return [Integer] Returns the number of lists that would be returned by the query.

    def self.count_lists(opts = {})
      q = build_query(opts)
      (q.nil?) ? 0 : q.count
    end

    # Build a query to find list items in this list.
    # This is a convenience method that returns an `ActiveRecord::Relation` on {BaseItem} with a
    # where clause that selects items belonging to `self`.
    #
    # @param opts [Hash] Additional options to pass to {BaseItem.build_query}; note that
    #  the **:lists** filter is ignored if present, since the method adds its own values for it.
    #
    # @return [ActiveRecord::Relation] Returns a relation that can be used to fetch the list items.

    def query_list_items(opts = {})
      f = {}.merge(opts)
      f[:filters] = { } unless f.has_key?(:filters)
      f[:filters][:lists] = { only: [ self ] }
      Fl::Core::List::BaseItem.build_query(f)
    end

    # Resolve a path to a list item.
    # This method splits the components of *path* and looks up the first one in the list; if it finds
    # a list item, and the item is a list, it calls itself recursively to resolve the rest of the path.
    # (Actually the algorithm is not recursive, but the end effect is the same.)
    #
    # Note tat the method executes a query for each component in the path, and therefore it does not have
    # the best performance.
    #
    # @param path [String] A path to the list item to look up; path components are separated by `/`
    #  (forward slash) characters.
    #
    # @return [Fl::Core::List::BaseItem,nil] Returns a list item if one is found; otherwise, it
    #  returns `nil`.

    def resolve_path(path)
      pl = path.split(Regexp.new("[\/\\\\]+"))
      pl.shift if pl[0].length < 1
      return nil if pl.count < 1
      
      list = self
      last = pl.pop
      pl.each do |pc|
        li = Fl::Core::List::BaseItem.where('(list_id = :lid) AND (name = :n)', lid: list.id, n: pc).first
        return nil if li.nil? || !li.listed_object.is_a?(Fl::Core::List::List)
        list = li.listed_object
      end

      Fl::Core::List::BaseItem.where('(list_id = :lid) AND (name = :n)', lid: list.id, n: last).first
    end
    
    protected

    # The default properties to return from `to_hash`.
    DEFAULT_HASH_KEYS = [ :caption_html, :caption_json, :title, :owner, :default_item_state_locked,
                          :list_display_preferences ]
    # The additional verbose properties to return from `to_hash`.
    VERBOSE_HASH_KEYS = [ :lists, :objects ]

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
    # @option opts [Hash] :to_hash[:objects] Hash options for the elements in the **:objects** key.
    #  The value is passed as the parameter to the `to_hash` call to the listed objects.
    #  Note that, to return objects in the hash, you have to place **:objects** in the **:include** key.
    #
    # @return [Hash] Returns a Hash containing the list representation.

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {}
      sp = nil
      keys.each do |k|
        case k
        when :lists
          l_opts = to_hash_opts_with_defaults(to_hash_opts[:lists], { verbosity: :id })
          rv[k] = self.lists.map do |l|
            l.to_hash(actor, l_opts)
          end
        when :objects
          o_opts = to_hash_opts_with_defaults(to_hash_opts[:objects], { verbosity: :id })
          rv[k] = self.objects.map do |obj|
            obj.to_hash(actor, o_opts)
          end
        when :owner
          o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], { verbosity: :minimal })
          rv[k] = self.owner.to_hash(actor, o_opts)
        when :list_items
          li_opts = to_hash_opts_with_defaults(to_hash_opts[:list_items], { verbosity: :minimal })
          rv[k] = self.list_items.map do |obj|
            obj.to_hash(actor, li_opts)
          end
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    private

    def set_objects(objs, owner)
      errs, conv = Fl::Core::List::BaseItem.normalize_objects(objs, self, owner)
      if errs > 0
        exc = NormalizationError.new(I18n.tx('fl.core.list.model.normalization_failure'), conv)
        raise exc
      else
        self.list_items = conv
      end
    end

    def set_fingerprints()
      self.owner_fingerprint = self.owner.fingerprint if self.owner
    end

    def check_list_items
      self.list_items.each_with_index do |li, idx|
        if !li.listed_object.respond_to?(:listable?) || !li.listed_object.listable?
          errors.add(:objects, I18n.tx('fl.core.list_item.model.not_listable',
                                       listed_object: li.listed_object.fingerprint))
        elsif self.persisted? && !li.list.id.nil? && (li.list.id != self.id)
          errors.add(:objects, I18n.tx('fl.core.list.model.validate.inconsistent_list',
                                       list_item: li.fingerprint, list: self.fingerprint))
        end

        li.sort_order = idx
      end
    end

    def before_validation_checks
      populate_title_if_needed(:caption_html, TITLE_LENGTH)
    end

    def before_save_checks
      populate_title_if_needed(:caption_html, TITLE_LENGTH)
    end
  end
end
