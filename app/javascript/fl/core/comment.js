const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('./object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('./model_factory');

/**
 * @ngdoc module
 * @name fl.models
 * @module fl
 * @description This module contains the model services for core data classes for the `fl-core` gem.
 *  These services are all registered with the {@sref FlGlobalModelFactory}.
 */

/**
 * @ngdoc type
 * @name FlCoreComment
 * @module fl.models
 * @requires FlModelBase
 * @description Model class for `Fl::Core::Comment`
 */

let FlCoreComment = FlClassManager.make_class({
    name: 'FlCoreComment',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name FlCoreComment#constructor
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
	 * @name FlCoreComment#refresh
	 * @description
	 *  Refresh the state of the instance based on the contents
	 *  of the hash representation of a Comment object.
	 *  The method converts the following properties:
	 *
	 *  - **commentable** into an object if the model factory supports it.
	 *  - **author** into an object if the model factory supports it.
	 *  - **contents_delta** into an object (from a JSON representation)
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

	    if (_.isString(data.contents_delta))
	    {
		this.contents_delta = JSON.parse(data.contents_delta);
	    }
	}
    },
    class_methods: {
	/**
	 * @ngdoc method
	 * @name FlCoreComment#create
	 * @classmethod
	 * @description
	 *  Factory for a user object.
	 *
	 * @param {Object} data The representation of the user object.
	 *
	 * @return {FlCoreComment} Returns an instance of {@sref FlCoreComment}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('FlCoreComment', data);
	}
    },
    extensions: [ ]
});

FlGlobalModelFactory.register('fl.models', [
    { service: FlCoreComment, class_name: 'Fl::Core::Comment' }
]);

module.exports = {
    FlCoreComment
};
