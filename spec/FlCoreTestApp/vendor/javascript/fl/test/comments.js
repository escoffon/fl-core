const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('fl/core/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/core/model_factory');

/**
 * @ngdoc module
 * @name fl.models
 * @module fl
 * @description This module contains the model services for core data classes for the `fl-core` gem.
 *  These services are all registered with the {@sref FlGlobalModelFactory}.
 */

/**
 * @ngdoc type
 * @name FlTestComment
 * @module fl.models
 * @requires FlModelBase
 * @description Model class for ``
 */

let FlTestComment = FlClassManager.make_class({
    name: 'FlTestComment',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name FlTestComment#constructor
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
	 * @name FlTestComment#refresh
	 * @description
	 *  Refresh the state of the instance based on the contents
	 *  of the hash representation of a Comment object.
	 *  The method converts the following properties:
	 *
	 *  - **commentable** into an object if the model factory supports it.
	 *  - **author** into an object if the model factory supports it.
	 *  - **contents_json** into an object (from a JSON representation)
	 *
	 * @param {Object} data An object containing a representation of the
	 *  comment object. This representation may be partial.
	 */

	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);

	    if (_.isObject(data.commentable))
	    {
		this.commentable = FlModelFactory.defaultFactory().create(data.commentable);
	    }

	    if (_.isObject(data.author))
	    {
		this.author = FlModelFactory.defaultFactory().create(data.author);
	    }

	    if (_.isString(data.contents_json))
	    {
		this.contents_json = JSON.parse(data.contents_json);
	    }
	}
    },
    class_methods: {
	/**
	 * @ngdoc method
	 * @name FlTestComment#create
	 * @classmethod
	 * @description
	 *  Factory for a user object.
	 *
	 * @param {Object} data The representation of the user object.
	 *
	 * @return {FlTestComment} Returns an instance of {@sref FlTestComment}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('FlTestComment', data);
	}
    },
    extensions: [ ]
});

FlGlobalModelFactory.register('fl.models', [
    { service: FlTestComment, class_name: '' }
]);

module.exports = {
    FlTestComment
};
