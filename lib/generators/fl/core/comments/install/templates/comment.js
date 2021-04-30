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
 * @name <%=@api_class_name%>
 * @module fl.models
 * @requires FlModelBase
 * @description Model class for `<%=@comment_class_name%>`
 */

let <%=@api_class_name%> = FlClassManager.make_class({
    name: '<%=@api_class_name%>',
    superclass: 'FlModelBase',
    /**
     * @ngdoc method
     * @name <%=@api_class_name%>#constructor
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
	 * @name <%=@api_class_name%>#refresh
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
	 * @name <%=@api_class_name%>#create
	 * @classmethod
	 * @description
	 *  Factory for a user object.
	 *
	 * @param {Object} data The representation of the user object.
	 *
	 * @return {<%=@api_class_name%>} Returns an instance of {@sref <%=@api_class_name%>}.
	 */

	create: function(data) {
	    return FlClassManager.modelize('<%=@api_class_name%>', data);
	}
    },
    extensions: [ ]
});

FlGlobalModelFactory.register('fl.models', [
    { service: <%=@api_class_name%>, class_name: '<%=@comment_class_name%>' }
]);

module.exports = {
    <%=@api_class_name%>
};
