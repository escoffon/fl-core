const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('fl/core/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/core/model_factory');

let TestActor = FlClassManager.make_class({
    name: 'TestActor',
    superclass: 'FlModelBase',
    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);
	}
    },
    class_methods: {
	create: function(data) {
	    return FlClassManager.modelize('TestActor', data);
	}
    },
    extensions: [ ]
});

let TestDatumOne = FlClassManager.make_class({
    name: 'TestDatumOne',
    superclass: 'FlModelBase',
    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);

	    if (_.isObject(data.owner))
	    {
	    	this.owner = FlModelFactory.defaultFactory().create(data.owner);
	    }
	}
    },
    class_methods: {
	create: function(data) {
	    return FlClassManager.modelize('TestDatumOne', data);
	}
    },
    extensions: [ ]
});

let TestDatumTwo = FlClassManager.make_class({
    name: 'TestDatumTwo',
    superclass: 'FlModelBase',
    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_properties: {
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);

	    if (_.isObject(data.owner))
	    {
	    	this.owner = FlModelFactory.defaultFactory().create(data.owner);
	    }
	}
    },
    class_methods: {
	create: function(data) {
	    return FlClassManager.modelize('TestDatumTwo', data);
	}
    },
    extensions: [ ]
});

FlGlobalModelFactory.register('fl.active_storage', [
    { service: TestActor, class_name: 'TestActor' },
    { service: TestDatumOne, class_name: 'TestDatumOne' },
    { service: TestDatumTwo, class_name: 'TestDatumTwo' }
]);

module.exports = { TestActor, TestDatumOne, TestDatumTwo };
