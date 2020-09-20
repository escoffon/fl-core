/**
 * @ngdoc module
 * @name fl.model_factory
 * @module fl
 * @requires fl.object_system
 * @description
 * Model factory
 * This module implements a factory of model object services.
 * It exports two services:
 * - {@sref FlModelCache}, a global cache of model instances.
 * - {@sref FlModelFactory}, a service that creates or refreshes model instances from hash representations.
 *
 * It also exports {@sref FlModelBase}, the base class for all model classes.
 */

const _ = require('lodash');
const jscache = require('js-cache');
const { FlExtensions, FlClassManager } = require('./object_system');

/**
 * @ngdoc type
 * @name FlModelBase
 * @module fl.model_factory
 * @extends FlRoot
 * @description
 *  The base class for model services.
 *
 *  A model service is an object that is instantiated once per existing instance of a data
 *  object in the client. Model services are organized in a class hierarchy that tracks the class
 *  organization of data objects in the server.
 * 
 *  ##### Managing data objects
 * 
 *  Each data class has a corresponding model service that inherits from FlModelBase and that defines
 *  the basic API configuration, and optionally adds subclass-specific functionality.
 *  Subclasses **must** define a class method called `type_class` that returns a string containing
 *  the name of the data class the service supports. They also typically define a `create` class method
 *  that returns a new instance of the class.
 *  The general outline of such subclass runs along these lines:
 *  1. Define class name, superclass, and initializer:
 *     <pre ng-non-bindable>
 *  let MyDatum = FlClassManager.make_class({
 *    name: 'MyDatum',
 *    superclass: 'FlModelBase',
 *    initializer: function(data) {
 *      this.&#95;&#95;super_init('FlModelBase', data);
 *      this.refresh(data);
 *    },</pre>
 *  2. This is followed by new and overridden instance methods, for example:
 *     <pre ng-non-bindable>
 *    instance_methods: {
 *      refresh: function(data) {
 *        this.&#95;&#95;super('FlModelBase', 'refresh', data);
 *        // additional processing of the instance data ...
 *      },
 *
 *      my_method: function(p1, p2) {
 *        return 'returns: ' + p1 + ' : ' + p2;
 *      }
 *    },</pre>
 *  3. And, finally, define class methods and extensions (mixins):
 *     <pre ng-non-bindable>
 *     class_methods: {
 *       type_class: function() {
 *         return 'My::Datum';
 *       },
 *       create: function(data) {
 *         return FlClassManager.modelize('MyDatum', data);
 *       }
 *     },
 *     extensions: {
 *       core: FlExtensions.FlCoreExtension
 *     }
 *   });</pre>
 * 
 * An object instance is created as follows:
 * <pre ng-non-bindable>
 *   let data = get_data_from_api_call();
 *   let obj = new MyDatum(data);
 * 
 *   // or, use the FlClassManager.modelize function:
 *   let obj2 = FlClassManager.modelize('MyDatum', data);
 * 
 *   // or, use the class method:
 *   let obj3 = MyDatum.create(data);
 * </pre>
 * Note that the initializer is called automatically when the object is created.
 * To make method calls on the object:
 * <pre ng-non-bindable>
 *   let concat = obj.my_method('one', 'two');
 * </pre>
 * 
 * @param {Object} data The data associated with the instance.
 */

let FlModelBase = FlClassManager.make_class({
    name: 'FlModelBase',
    initializer: function(data) {
	this.__super_init('FlRoot');
	this.refresh(data);
    },
    instance_methods: {
	/**
	 * @ngdoc method
	 * @name FlModelBase#refresh
	 * @description Refresh the state of the instance based on the contents
	 *  of the hash representation of an object.
	 * 
	 *  This method also validates that a refresh does not change the class type and object
	 *  identifier, if they are already set. This check prevents clients for creating an instance
	 *  of a given model class, and later change its "type" to another class.
	 *  Note that subclasses that override this method **must** call the superclass implementation
	 *  in order to trigger these checks (and the core loading functionality).
	 *
	 * @param {Object} data An object containing a representation of the 
	 *  server object. This representation may be partial.
	 *
	 * @throws Throws an exception if the properties **type** and **fingerprint** already exist
	 *  in `this`, and their value is different from those in *data*.
	 */

	refresh: function(data) {
	    if (!_.isUndefined(this.type) && !_.isUndefined(data.type) && (this.type != data.type))
	    {
		throw new Error('type mismatch in model data refresh');
	    }
	    
	    if (!_.isUndefined(this.fingerprint) && !_.isUndefined(data.fingerprint)
		&& (this.fingerprint != data.fingerprint))
	    {
		throw new Error('fingerprint mismatch in model data refresh');
	    }
	    
	    let self = this;
	    _.forEach(data, function(v, k) {
		self[k] = self._convert_value(v);
	    });

	    if (!_.isNil(data.created_at)) self.created_at = new Date(data.created_at);
	    if (!_.isNil(data.updated_at)) self.updated_at = new Date(data.updated_at);
	},

	/**
	 * @ngdoc method
	 * @name FlModelBase#has_permission
	 * @description
	 *  Check if the object has granted a permission to the current user.
	 *  This method looks up the property **permissions**, and if present it then supports two
	 *  types of checks. If **permissions** is an object, and *op* is a property of **permissions**
	 *  with value `true`, then it returns `true`.
	 *  If **permissions** is an array that includes *op*, then it returns `true`.
	 *  Otherwise, it returns `false`.
	 * 
	 * @param {String} op The name of the permission to check; for example, `read` or `write`.
	 *
	 * @return {Boolean} Returns `true` if permission is granted, `false` otherwise.
	 */

	has_permission: function(op) {
	    // We need to do the array check first because an array will also return true for isObject

	    if (_.isArray(this.permissions))
	    {
		return _.includes(this.permissions, op);
	    }
	    else if (_.isObject(this.permissions))
	    {
		return (this.permissions[op] == true);
	    }
	    else
	    {
		return false;
	    }
	},

	_convert_value: function(value) {
	    let self = this;
		
	    if (_.isArray(value))
	    {
		return _.map(value, function(av, aidx) {
		    return self._convert_value(av);
		});
	    }
	    else if (_.isObject(value))
	    {
		return _.reduce(value, function(acc, ov, ok) {
		    acc[ok] = self._convert_value(ov);
		    return acc;
		}, { });
	    }
	    else
	    {
		return value;
	    }
	},


	/**
	 * @ngdoc method
	 * @name FlModelBase#_convert_JSON_value
	 * @description
	 *  Convert a JSON representation to a Javascript value.
	 *  If *value* is a string: if it is the string `null`, convert to the `null` value; otherwise,
	 *  convert to Javascript via a call to `JSON.parse`.
	 *  If *value* is not a string, return it as is.
	 * 
	 * @param {any} value The value to convert.
	 *
	 * @return {any} Returns the converted value.
	 */
	
	_convert_JSON_value: function(value) {
	    if (_.isString(value)) {
		return (value == 'null') ? null : JSON.parse(value);
	    }

	    return value;
	}
    },
    class_methods: {
    },
    extensions: [ ]
});

/**
 * @ngdoc service
 * @name FlModelCache
 * @module fl.model_factory
 * @description
 * A service that manages a cache of model instances.
 * This cache is global across the application.
 */

let FlModelCache = (function() {
    function _type(h) {
	let s = (_.isString(h)) ? h : ((_.isString(h.virtual_type)) ? h.virtual_type : h.type);
	return (_.isNil(s)) ? null : s.replace(/::/g, '');
    };

    function _id(h) {
	if (h.hasOwnProperty('fingerprint'))
	{
	    return h.fingerprint;
	}
	else if (h.hasOwnProperty('id'))
	{
	    return h.id;
	}
	else if (h.type == 'Paperclip::Attachment')
	{
	    if (h.hasOwnProperty('urls'))
	    {
		return h.urls.original;
	    }
	    else
	    {
		return h.original;
	    }
	}
	else
	{
	    return undefined;
	}
    };

    function _cache_id(h) {
	let id = _id(h);
	return (id == undefined) ? undefined : (_type(h) + '/' + id);
    };

    function FlModelCache() {
	this._model_cache = new jscache();
    };
    FlModelCache.prototype.constructor = FlModelCache;
    
    /**
     * @ngdoc method
     * @name FlModelCache#get
     * @description
     *  Gets a model instance from the cache, if one is present.
     * @param {Object} h An object containing the model's description. The factory
     *  typically expects two properties, *type* and *id*, as described below.
     *  However, it can also handle Paperclip attachments, which don't have an *id*
     *  property since they don't really live in the database (Paperclip attachments are
     *  manufactured on the fly from specialized attributes in a Rails model): in that
     *  case, the identifier is the URL of the original file representation.
     * 
     * @property {String} h.type A string containing the Rails name of the model class,
     *  for example *Fl::Core::User*.
     * @property h.id An integer or string value containing the object identifier in the
     *  database.
     * @property {Object} h.urls If this is a Paperclip attachment, this is an object containing
     *  the attachment's URLs; the identifier is the value of the *original* property.
     * 
     * @return Returns an instance of a model service, if one is present in the cache.
     */

    FlModelCache.prototype.get = function(h) {
	let id = _cache_id(h);
	return (id == undefined) ? null : this._model_cache.get(id);
    };

    /**
     * @ngdoc method
     * @name FlModelCache# put
     * @description
     *  Puts a model instance in the cache.
     * 
     * @param o The model instance to place in the cache.
     */

    FlModelCache.prototype.put = function(o) {
	let id = _cache_id(o);
	if (id != undefined) this._model_cache.set(id, o);
    };

    /**
     * @ngdoc method
     * @name FlModelCache#remove
     * @description
     *  Removes a model instance from the cache.
     * 
     * @param o The model instance to remove from the cache.
     */

    FlModelCache.prototype.remove = function(o) {
	let id = _cache_id(o);
	if (id != undefined) this._model_cache.del(id);
    };

    /**
     * @ngdoc method
     * @name FlModelCache#clear
     * @description
     *  Clears the cache.
     */

    FlModelCache.prototype.clear = function() {
	this._model_cache.clear();
    };

    /**
     * @ngdoc method
     * @name FlModelCache#size
     * @description
     *  Returns the number of cached records.
     *
     * @return Returns the number of objects in the cache.
     */

    FlModelCache.prototype.size = function() {
	return this._model_cache.size();
    };

    return FlModelCache;
})();

/**
 * @ngdoc service
 * @name FlModelFactory
 * @module fl.model_factory
 * @description
 * A service that manages a registry of names of model services.
 *
 *  For example, a module registers its known model services as follows:
 *  <pre ng-non-bindable>
 *    const { FlClassManager } = require('fl/framework/object_system');
 *    const { FlModelBase, FlGlobalModelFactory } = require('fl/framework/model_factory');
 *
 *    let MyModelOne = FlClassManager.make_class({
 *      name: 'MyModelOne',
 *      superclass: 'FlModelBase',
 *      ...
 *    });
 *
 *    let MyModelTwo = FlClassManager.make_class({
 *      name: 'MyModelTwo',
 *      superclass: 'FlModelBase',
 *      ...
 *    });
 *
 *    FlGlobalModelFactory.register('my_module_name', [
 *      { service: MyModelOne, class_name: 'My::Model::One' },
 *      { service: MyModelTwo, class_name: 'My::Other::Model' }
 *    ]);
 *  </pre>
 */

let FlModelFactory = (function() {
    function _type(h) {
	let s = (_.isString(h)) ? h : ((_.isString(h.virtual_type)) ? h.virtual_type : h.type);
	return (_.isNil(s)) ? null : s.replace(/::/g, '');
    };

    function FlModelFactory() {
	this._model_cache = new FlModelCache();
	this._model_services = { };
    }
    FlModelFactory.prototype.constructor = FlModelFactory;

    /**
     * @ngdoc method
     * @name FlModelFactory#register
     * @description Register model factory services provided by a module.
     * 
     * @param {String} module The module's name.
     * @param {Array} services Array of factory services provided by this module.
     *  Each element is an object that contains two properties: **service** is the class object for
     *  the model service, and **class_name** is the name of the (Rails) class associated with this model.
     *  The value of **class_name** is used as the lookup key in the model service registry.
     */

    FlModelFactory.prototype.register = function(module, services) {
	let self = this;
	
	_.forEach(services, function(srv, idx) {
	    if (_.isNil(srv.class_name))
	    {
		console.log("(FlModelFactory): missing service class name in '" + module + "'");
	    }
	    else
	    {
		let name = _type(srv.class_name);
		
		if (_.isNil(srv.service))
		{
		    console.log("(FlModelFactory): missing service object in (" + module + ")'"
				+ srv.class_name + "'");
		}
		else
		{
		    if (_.isObject(self._model_services[name])
			&& (self._model_services[name].module != module))
		    {
			console.log("(FlModelFactory): service (" + module + ")'"
				    + srv.class_name + "' is already registered in module '"
				    + self._model_services[name].module + "' and will overwrite it");
		    }
			
		    self._model_services[name] = _.merge({ module: module }, srv);
		}
	    }
	});
    };

    /**
     * @ngdoc method
     * @name FlModelFactory#unregister
     * @description Unregister the model factory services provided by a module.
     *  This method is provided mostly to support testing.
     * 
     * @param {String} module The module's name.
     */

    FlModelFactory.prototype.unregister = function(module) {
	let name = _type(module);

	if (!_.isNil(this._model_services[name])) delete this._model_services[name];
    };
    
    /**
     * @ngdoc method
     * @name FlModelFactory#service_for
     * @description Gets a registered service.
     * 
     * @param {String|Object} cname If the value is a string, it is the name of the data class
     *  to look up. If it is an object, it is a representation of a model's data, and is expected to
     *  have the property **type** (and optionally **virtual_type**), which contains the name of the data class.
     *  If **virtual_type** is present, use that value for the name of the data class; otherwise, use **type**.
     *  The virtual type is defined by some classes that want to use a generic type name instead of the
     *  specific one; for example, a class that is stored via ActiveRecord and one stored in Neo4j may both
     *  map to a generic one at the API level.
     *
     * @return {Object} Returns the service object that was registered under _cname_; if no service
     *  object is registered under that name, returns `null`.
     */

    FlModelFactory.prototype.service_for = function(cname) {
	let cn = _type(cname);
	return (_.isObject(this._model_services[cn])) ? this._model_services[cn].service : null;
    };
    
    /**
     * @ngdoc method
     * @name FlModelFactory#services
     * @description Gets the registered services.
     * 
     * @return {Object} Returns an object listing all registered model services; the properties
     *  are data class names, and the values are objects containing the service description:
     *  - **name** is the data class name.
     *  - **service** is the service object.
     *  - **module** is the name of the module that registered this service.
     */

    FlModelFactory.prototype.services = function() {
	return this._model_services;
    };
    
    /**
     * @ngdoc method
     * @name FlModelFactory#cache
     * @description Gets the model cache used by the factory.
     * 
     * @return {FlModelCache} Returns the instance of {@sref FlModelCache} used by the factory for
     *  managing the model instances.
     */

    FlModelFactory.prototype.cache = function() {
	return this._model_cache;
    };

    FlModelFactory.prototype._create_internal = function(h, null_on_failure) {
	let o = this._model_cache.get(h);
	if (o)
	{
	    o.refresh(h);
	}
	else
	{
	    let srv = this.service_for(h);
	    if (srv)
	    {
		o = new srv(h);
		this._model_cache.put(o);
	    }
	    else
	    {
		o = (null_on_failure) ? null : h;
	    }
	}

	return o;
    };

    /**
     * @ngdoc method
     * @name FlModelFactory#create
     * @description Create an instance or an array of instances based on the hash
     *  representation of objects. Objects already in the cache are refreshed with
     *  the contents of the representation before they are returned.
     * 
     * @param {Object|Array} obj_or_array The object containing a model instance's
     *  properties, or and array of objects containing multiple model instances.
     * @param {Boolean} null_on_failure If the value is truthy, then if an instance cannot be built
     *  the return value is `null`; otherwise, the original argument is returned.
     *  The default is to return the original argument on failure, so that classes that convert properties
     *  from a simple object to a class instance are still left with the simple object on conversion failure.
     * 
     * @return If *obj_or_array* is an object, returns the
     *  corresponding model instance (or `null` if no instance could be built).
     *  If an array, returns an array of model instances.
     */

    FlModelFactory.prototype.create = function(obj_or_array, null_on_failure) {
	if (obj_or_array)
	{
	    if (_.isArray(obj_or_array))
	    {
		let self = this;
		return _.map(obj_or_array, function(v, idx) {
		    return self._create_internal(v, null_on_failure);
		});
	    }
	    else
	    {
		return this._create_internal(obj_or_array, null_on_failure);
	    }
	}
	else
	{
	    return null;
	}
    };

    return FlModelFactory;
})();

/**
 * @ngdoc service
 * @name FlGlobalModelFactory
 * @module fl.model_factory
 * @description
 * The global model factory. This is an instance of {@sref FlModelFactory} that is globally accessible
 * and can be used as the applicationwide model factory.
 */

const FlGlobalModelFactory = new FlModelFactory();

let _default_factory = FlGlobalModelFactory;

/**
 * @ngdoc method
 * @name FlModelFactory#create
 * @classmethod
 * @description Return the default model factory instance.
 *  The initial value is {@sref FlGlobalModelFactory}.
 * 
 * @return Returns the instance of {@sref FlModelFactory} to use for creating model instances.
 */

FlModelFactory.defaultFactory = function() {
    return _default_factory;
};

module.exports = { FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory };
