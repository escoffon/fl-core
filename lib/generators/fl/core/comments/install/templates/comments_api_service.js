const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('fl/core/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/core/model_factory');
const {
    FlAPIService, FlAPIServiceRegistry, FlGlobalAPIServiceRegistry
} = require('fl/core/api_services');

// This is imported so that webpack pulls in the sources, or we run the risk of not loading it
const { <%=@api_class_name%> } = require('<%=@api_pathname%>');

const API_CFG = {
    root_url_template: '<%=@api_service_root%>',
    namespace: '<%=@api_namespace%>',
    data_names: [ 'comment', 'comments' ]
};

/**
 * @ngdoc type
 * @name <%=@api_service_class_name%>
 * @module fl.services
 * @requires FlAPIService
 * @description API service class for communicating with the user API.
 *  This API service manages interactions with the API for `Fl::Core::Comment` objects.
 */

let <%=@api_service_class_name%> = FlClassManager.make_class({
    name: '<%=@api_service_class_name%>',
    superclass: 'FlAPIService',
    /**
     * @ngdoc method
     * @name <%=@api_service_class_name%>#constructor
     * @description The constructor; called during `new` creation.
     *  Calls the superclass implementation, passing the following API configuration:
     *  ```
     *  {
     *    root_url_template: '<%=@api_service_root%>',
     *    namespace: '<%=@api_namespace%>',
     *    data_names: [ 'comment', 'comments' ]
     *  }
     *  ```
     *  and passing *srv_cfg* as the second argument.
     *
     * @param {Object} srv_cfg Configuration for the service.
     */

    initializer: function(srv_cfg) {
	this.__super_init('FlAPIService', API_CFG, srv_cfg);
    },

    instance_properties: {
    },

    instance_methods: {
	/**
	 * @ngdoc method
	 * @name <%=@api_service_class_name%>#commentable_comments
	 * @description Wrapper for an :index call for a given commentable.
	 *  The method sets the value of **only_commentables** to *commentable*, removes **except_commentables**,
	 *  and then calls the the {@sref FlAPIService#index} method.
	 *
	 * @param {Object|String} commentable The commentable to use as the context for the query. A string value
	 *  is passed as is, an object value is expected to have a **fingerprint** property, which is used as the
	 *  **only_commentables** value.
	 * @param {Object} [params] Additional parameters to pass in the request; the contents of this object are
	 *  merged into *config.params*, and eventually make their way to the query string.
	 *  A common parameter here is **_q**, which contains the query options (**only_commentables** is set inside
	 *  of **_q**).
	 * @param {Object} [config] Configuration object to pass to `axios.get`; this object is
	 *  merged into the default HTTP configuration object.
	 *
	 * @return On success, returns a resolved promise containing the response data converted
	 *  to an array of model objects.
	 *  On error, returns a promise that rejects with the value
	 *  from the {@sref FlAPIService#index} method.
	 *  The error and response objects are also saved in the {@sref FlAPIService#error} and 
	 *  {@sref FlAPIService#response} properties, respectively.
	 */

	commentable_comments: function(commentable, params, config) {
	    if (_.isNil(params)) params = { };
	    let _q = _.isUndefined(params._q) ? { } : _.merge({ }, params._q);

	    if (!_.isObject(_q.filters)) _q.filters = { };
	    _q.filters.commentables = {
		only: (_.isString(commentable)) ? [ commentable ] : [ commentable.fingerprint ]
	    };

	    let p = _.merge({ }, params, { _q: _q });
	    return this.index(p, config);			    
	},

	/**
	 * @ngdoc method
	 * @name <%=@api_service_class_name%>#add_comment
	 * @description Creates a comment associated with a given commentable.
	 *  The method sets up the appropriate submission parameters, and then calls the the
	 *  {@sref FlAPIService#create} method.
	 *
	 * @param {Object|String} commentable The commentable to use as the context for the comment. A string value
	 *  is passed as is, an object value is expected to have a **fingerprint** property, which is used as the
	 *  **commentable** submission parameter.
	 * @param {String} contents_html The comment contents, in HTML.
	 * @param {Object|String} contents_json The comment contents, in JSON format. A string value is
	 *  used as is, an object is converted to a JSON representation.
	 * @param {String} [title] The comment title, if any.
	 * @param {Object|String} author The author of the comment. Currently this argument is ignored, but it is
	 *  defined in the method signature in case the API supports configurable authors in the future.
	 *  Currently, the author is the current authenticated user.
	 * @param {Object} [config] Configuration object to pass to the `create` method; this object is
	 *  merged into the default HTTP configuration object.
	 *
	 * @return On success, returns a resolved promise containing the response data.
	 *  On error, returns a promise that rejects with the value
	 *  from the {@sref FlAPIService#post} method.
	 *  The error and response objects are also saved in the {@sref FlAPIService#error} and 
	 *  {@sref FlAPIService#response} properties, respectively.
	 */

	add_comment: function(commentable, contents_html, contents_json, title, author, config) {
	    let cp = {
		commentable: (_.isString(commentable)) ? commentable : commentable.fingerprint,
		contents_html: contents_html,
		contents_json: (_.isObject(contents_json)) ? JSON.stringify(contents_json) : contents_json
	    };
	    if (!_.isNil(title)) cp.title = title;

	    return this.create({ wrapped: cp }, config);
	}
    },
    
    class_methods: {
    },
    
    extensions: [ ]
});

FlGlobalAPIServiceRegistry.register('fl.services', { <%=@api_service_class_name%>: '<%=@api_class_name%>' });

module.exports = { <%=@api_service_class_name%> };
