/**
 * @ngdoc module
 * @name fl.active_storage
 * @requires fl.model_factory
 * @description
 * Support for ActiveRecord models.
 */

const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('./object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('./model_factory');

/**
 * @ngdoc type
 * @name ActiveStorageAttachment
 * @module fl.active_storage
 * @requires FlModelBase
 * @description Model class for `ActiveStorage::Attachment`
 *  This model encapsulate an instance of an ActiveStorage attachment object.
 *  In addition to a number of metadata properties, the object contains an array of *variants*,
 *  representation of the original data that have been transformed. Typically, image attachments
 *  contain a number of variants (usually for different image sizes), whereas nonimage ones
 *  include just the `original` style, the original file itself.
 */

let ActiveStorageAttachment = FlClassManager.make_class({
    name: 'ActiveStorageAttachment',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name ActiveStorageAttachment#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the value of *data*.
     *
     * @param {Object} data Model data.
     */

    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachment#refresh
	 * @description
	 *  Refresh the state of the instance based on the contents
	 *  of the hash representation of an attachment object.
	 * 
	 * @param {Object} data An object containing a representation of the 
	 *  attachment object. This representation may be partial.
	 *
	 * @return [Boolean] Returns `true` if the state was refreshed from *data*, `false* otherwise.
	 */

	refresh: function(data) {
	    if (!this.__super('FlModelBase', 'refresh', data)) return false;

	    if (!_.isArray(this.variants)) this.variants = [ ];

	    return true;
	},

	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachment#variant
	 * @description
	 *  Returns the variant descriptor for a given style.
	 * 
	 * @param {String} style The name of the style to look up.
	 *
	 * @return {Object} Returns an object containing the description of the variant:
	 *
	 *  - **style** is the style name (should be equal to *style*).
	 *  - **params** is an object of processing parameters that were used to generate the
	 *    variant. A useful parameter is **resize**, the target size for the variant.
	 *  - **url** The path component of the URL to the variant file.
	 *
	 *  Returns `undefined` if *style* is not in the attachments.
	 */

	variant: function(style) {
	    let ls = style.toLowerCase();
	    
	    return _.find(this.variants, function(v, idx) {
		return v.style.toLowerCase() == ls;
	    });
	},

	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachment#variant_url
	 * @description
	 *  Returns the variant URL for a given style.
	 * 
	 * @param {String} style The name of the style to look up.
	 *
	 * @return {String} Returns a string containing the path component of the variant URL,
	 *  `null` if *style* is not in the list of variants.
	 */

	variant_url: function(style) {
	    let v = this.variant(style);
	    
	    return (_.isObject(v)) ? v.url : null;
	}
    },
    class_methods: {
	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachment#create
	 * @classmethod
	 * @description
	 *  Factory for an attachment object.
	 * 
	 * @param {Object} data The representation of the user object.
	 * 
	 * @return {ActiveStorageAttachment} Returns an instance of {@sref ActiveStorageAttachment}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('ActiveStorageAttachment', data);
	}
    },
    extensions: [ ]
});

/**
 * @ngdoc type
 * @name ActiveStorageAttachedOne
 * @module fl.active_storage
 * @requires FlModelBase
 * @description Model class for `ActiveStorage::Attached::One`
 *  This model encapsulate an instance of a `has_one_attached` relationship.
 */

let ActiveStorageAttachedOne = FlClassManager.make_class({
    name: 'ActiveStorageAttachedOne',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name ActiveStorageAttachedOne#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the value of *data*.
     *
     * @param {Object} data Model data.
     */

    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
	/**
	 * @ngdoc property
	 * @name ActiveStorageAttachedOne#attachment
	 * @description Accessor for the one attachment in the relationship.
	 *  This property returns the value of *this.attachments[0]*.
	 *
	 * @return {ActiveStorageAttachment} The attachment object.
	 */

	attachment: {
	    get: function() { return this.attachments[0]; },
	    set: function(attachment) { }
	}
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachedOne#refresh
	 * @description
	 *  Refresh the state of the instance based on the contents
	 *  of the hash representation of a ActiveStorageAttachedOne object.
	 *  The **attachments** property, if present, is converted to an array of
	 *  {@sref ActiveStorageAttachment} instances.
	 * 
	 * @param {Object} data An object containing a representation of the 
	 *  proxy object. This representation may be partial.
	 *
	 * @return [Boolean] Returns `true` if the state was refreshed from *data*, `false* otherwise.
	 */

	refresh: function(data) {
	    if (!this.__super('FlModelBase', 'refresh', data)) return false;

	    if (_.isArray(data.attachments))
	    {
		// Since attachments don't have an identifier, they cannot be cached, and we
		// create them directly.
		
		this.attachments = _.map(data.attachments, function(a, idx) {
		    return new ActiveStorageAttachment(a);
		});
	    }

	    return true;
	},

	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachedOne#variant
	 * @description
	 *  Returns the variant descriptor for a given style for the single attachment.
	 *  This is a convenience method that checks if the attachment is non-null, and if so calls
	 *  `variant` against it.
	 * 
	 * @param {String} style The name of the style to look up.
	 *
	 * @return {Object} Returns an object containing the description of the variant:
	 *
	 *  - **style** is the style name (should be equal to *style*).
	 *  - **params** is an object of processing parameters that were used to generate the
	 *    variant. A useful parameter is **resize**, the target size for the variant.
	 *  - **url** The path component of the URL to the variant file.
	 *
	 *  Returns `undefined` if *style* is not in the attachments.
	 */

	variant: function(style) {
	    if (_.isNil(this.attachment)) return undefined;

	    return this.attachment.variant(style);
	},

	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachedOne#variant_url
	 * @description
	 *  Returns the variant URL for a given style for the single attachment.
	 *  This is a convenience method that checks if the attachment is non-null, and if so calls
	 *  `variant_url` against it.
	 * 
	 * @param {String} style The name of the style to look up.
	 *
	 * @return {String} Returns a string containing the path component of the variant URL,
	 *  `null` if *style* is not in the list of variants.
	 */

	variant_url: function(style) {
	    if (_.isNil(this.attachment)) return undefined;

	    return this.attachment.variant_url(style);
	}
    },
    class_methods: {
	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachedOne#create
	 * @classmethod
	 * @description
	 *  Factory for a `has_one_attached` relationship object.
	 * 
	 * @param {Object} data The representation of the relationship object.
	 * 
	 * @return {ActiveStorageAttachedOne} Returns an instance of {@sref ActiveStorageAttachedOne}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('ActiveStorageAttachedOne', data);
	}
    },
    extensions: [ ]
});

/**
 * @ngdoc type
 * @name ActiveStorageAttachedMany
 * @module fl.active_storage
 * @requires FlModelBase
 * @description Model class for `ActiveStorage::Attached::Many`
 *  This model encapsulate an instance of a `has_many_attached` relationship.
 */

let ActiveStorageAttachedMany = FlClassManager.make_class({
    name: 'ActiveStorageAttachedMany',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name ActiveStorageAttachedMany#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the value of *data*.
     *
     * @param {Object} data Model data.
     */

    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachedMany#refresh
	 * @description
	 *  Refresh the state of the instance based on the contents
	 *  of the hash representation of a ActiveStorageAttachedMany object.
	 *  The **attachments** property, if present, is converted to an array of
	 *  {@sref ActiveStorageAttachment} instances.
	 * 
	 * @param {Object} data An object containing a representation of the 
	 *  proxy object. This representation may be partial.
	 *
	 * @return [Boolean] Returns `true` if the state was refreshed from *data*, `false* otherwise.
	 */

	refresh: function(data) {
	    if (!this.__super('FlModelBase', 'refresh', data)) return false;

	    if (_.isArray(data.attachments))
	    {
		// Since attachments don't have an identifier, they cannot be cached, and we
		// create them directly.
		
		this.attachments = _.map(data.attachments, function(a, idx) {
		    return new ActiveStorageAttachment(a);
		});
	    }

	    return true;
	}
    },
    class_methods: {
	/**
	 * @ngdoc method
	 * @name ActiveStorageAttachedMany#create
	 * @classmethod
	 * @description
	 *  Factory for a `has_many_attached` relationship object.
	 * 
	 * @param {Object} data The representation of the relationship object.
	 * 
	 * @return {ActiveStorageAttachedMany} Returns an instance of {@sref ActiveStorageAttachedMany}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('ActiveStorageAttachedMany', data);
	}
    },
    extensions: [ ]
});

FlGlobalModelFactory.register('fl.active_storage', [
    { service: ActiveStorageAttachment, class_name: 'ActiveStorage::Attachment' },
    { service: ActiveStorageAttachedOne, class_name: 'ActiveStorage::Attached::One' },
    { service: ActiveStorageAttachedMany, class_name: 'ActiveStorage::Attached::Many' }
]);

module.exports = { ActiveStorageAttachment, ActiveStorageAttachedOne, ActiveStorageAttachedMany };
