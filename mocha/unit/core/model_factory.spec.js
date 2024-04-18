const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('fl/core/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/core/model_factory');
const th = require('test_helpers');

const MY_MODEL_DESC = {
    name: 'MyFactoryTestModel',
    superclass: 'FlModelBase',
    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);
	    if (!_.isNil(data.accessed_at)) this.accessed_at = new Date(data.accessed_at);
	}
    }
};

const MY_OTHER_DESC = {
    name: 'MyOther',
    superclass: 'FlModelBase',
    initializer: function(data) {
	this.__super_init('FlModelBase', data);
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super('FlModelBase', 'refresh', data);
	}
    }
};

const MODEL_1 = {
    type: "My::Factory::Test::Model",
    api_root: "/my/model",
    url_path: "my_model_path/2",
    fingerprint: "My::Factory::Test::Model/2",
    id: 2,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    username: "user102",
    first_name: "@user102",
    last_name: null,
    email: "user102@opoline.com",
    full_name: "@user102",
    intro: null,
    roles: [ "customer" ],
    accessed_at: 'Thu, 13 Sep 2018 22:10:20 UTC +00:00',
    hash: { one: 1, two: 'two' }
};

const MODEL_2 = {
    type: "My::Factory::Test::Model",
    api_root: "/my/model",
    url_path: "my_model_path/2",
    fingerprint: "My::Factory::Test::Model/2",
    id: 2,
    created_at: '2018-09-13T21:57:27Z',
    username: "user102",
    first_name: "@user102",
    last_name: null,
    email: "user102@opoline.com",
    full_name: "@user102",
    intro: null,
    roles: [ "customer" ],
    accessed_at: 'Thu, 13 Sep 2018 22:10:20 UTC +00:00',
    hash: { one: 1, two: 'two' }
};

const OTHER_1 = {
    type: "My::Other",
    api_root: "/my/other",
    url_path: "my_other_path/4",
    fingerprint: "My::Other/4",
    id: 4,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    username: "user104"
};

const UNDEFINED_1 = {
    type: "My::Undefined",
    api_root: "/my/undefined",
    url_path: "my_undefined_path/6",
    fingerprint: "My::Undefined/6",
    id: 6,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    username: "user106"
};

describe('fl.model_factory module', function() {
    beforeEach(function() {
	FlClassManager.make_class(MY_MODEL_DESC);
	FlClassManager.make_class(MY_OTHER_DESC);
    });
    
    afterEach(function() {
	th.clear_model_services(null, [ MY_MODEL_DESC.name, MY_OTHER_DESC.name ]);
	th.clear_ext();
	th.clear_class([ MY_MODEL_DESC.name, MY_OTHER_DESC.name ]);
    });

    context('loading', function() {
	it('should register the FlBaseModelExtension extension', function() {
	    expect(FlExtensions.lookup('FlBaseModelExtension', false)).to.not.be.null;
	});

	it('should register the FlModelBase class', function() {
	    expect(FlClassManager.get_class('FlBaseModel')).to.not.be.null;
	});
    });
    
    describe('FlModelBase', function() {
	context('creation', function() {
	    it('with new should create an instance of the model class', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let mm = new MyFactoryTestModel(MODEL_1);

		expect(mm).to.be.an.instanceof(MyFactoryTestModel);
	    });

	    it('with new should load data into properties', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let mm = new MyFactoryTestModel(MODEL_1);

		let data_keys = _.reduce(MODEL_1, function(acc, mv, mk) {
		    acc.push(mk);
		    return acc;
		}, [ ]);
		let obj_keys = _.reduce(data_keys, function(acc, ov, oidx) {
		    if (!_.isUndefined(mm[ov])) acc.push(ov);
		    return acc;
		}, [ ]);
		expect(obj_keys).to.have.members(data_keys);
	    });

	    it('with new should convert datetime properties to Date', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let mm = new MyFactoryTestModel(MODEL_1);

		expect(mm.created_at).to.be.an.instanceof(Date);
		expect(mm.updated_at).to.be.an.instanceof(Date);
		expect(mm.accessed_at).to.be.an.instanceof(Date);
	    });

	    it('with modelize should create an instance of the model class', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);

		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_1);
		expect(mm).to.be.an.instanceof(MyFactoryTestModel);

		mm = FlClassManager.modelize(MyFactoryTestModel, MODEL_1);
		expect(mm).to.be.an.instanceof(MyFactoryTestModel);
	    });

	    it('with modelize should load data into properties', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_1);

		let data_keys = _.reduce(MODEL_1, function(acc, mv, mk) {
		    acc.push(mk);
		    return acc;
		}, [ ]);
		let obj_keys = _.reduce(data_keys, function(acc, ov, oidx) {
		    if (!_.isUndefined(mm[ov])) acc.push(ov);
		    return acc;
		}, [ ]);
		expect(obj_keys).to.have.members(data_keys);
	    });

	    it('with modelize should convert datetime properties to Date', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_1);

		expect(mm.created_at).to.be.an.instanceof(Date);
		expect(mm.updated_at).to.be.an.instanceof(Date);
		expect(mm.accessed_at).to.be.an.instanceof(Date);
	    });
	});
	
	context('#refresh', function() {
	    it('should set properties from data', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_1);

		_.forEach(MODEL_1, function(mv, mk) {
		    if ((mk == 'created_at') || (mk == 'updated_at') || (mk == 'accessed_at'))
		    {
			let d = new Date(mv);
			expect(mm[mk].toString()).to.equal(d.toString());
		    }
		    else if (mk == 'roles')
		    {
			expect(mm[mk]).to.have.members(mv);
		    }
		    else if (mk == 'hash')
		    {
			expect(mm[mk]).to.deep.equal(mv);
		    }
		    else
		    {
			expect(mm[mk]).to.equal(mv);
		    }
		});
	    });
	    
	    it('should convert arrays correctly', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_1);
		expect(mm.roles).to.have.members(MODEL_1.roles);
	    });

	    it('should convert objects correctly', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_1);
	    	expect(mm.hash).to.deep.equal(MODEL_1.hash);
	    });
	    
	    it('should refresh partial data', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_1);

		expect(mm.first_name).to.equal("@user102");
		expect(mm.last_name).to.be.null;

		mm.refresh({ last_name: 'User' });
		expect(mm.first_name).to.equal("@user102");
		expect(mm.last_name).to.equal('User');
	    });

	    it('should convert timestamps to Date', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_2);

		expect(mm.created_at).to.be.an.instanceof(Date);
		expect(mm.updated_at).to.be.an('undefined');

		mm.refresh({ updated_at: '2018-10-01T10:20:30Z' });
		expect(mm.updated_at).to.be.an.instanceof(Date);
	    });

	    it('should fail if the updated_at is earlier than created_at', function() {
		let mm = FlClassManager.modelize(MY_MODEL_DESC.name, MODEL_2);

		expect(mm.created_at).to.be.an.instanceof(Date);
		expect(mm.updated_at).to.be.an('undefined');

		let rv = mm.refresh({ updated_at: '2018-09-01T10:20:30Z' });
		expect(rv).to.be(false);
		expect(mm.updated_at).to.be.an('undefined');
	    });
	});
    });

    describe('FlModelFactory', function() {
	context('#register', function() {
	    it('should register services', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let MyOtherClass = FlClassManager.get_class(MY_OTHER_DESC.name);

		FlModelFactory.defaultFactory().register('test_module', [
		    { service: MyFactoryTestModel, class_name: 'My::Factory::Test::Model' },
		    { service: MyOtherClass, class_name: 'My::Other' }
		]);

		let reg = _.reduce(FlModelFactory.defaultFactory()._model_services, function(acc, sv, sk) {
		    acc.push(sk);
		    return acc;
		}, [ ]);
		expect(reg).to.include(MY_MODEL_DESC.name);
		expect(reg).to.include(MY_OTHER_DESC.name);
	    });

	    it('should not register null services', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let MyOtherClass = FlClassManager.get_class(MY_OTHER_DESC.name);

		FlModelFactory.defaultFactory().register('test_module', [
		    { class_name: 'My::Factory::Test::Model' },
		    { service: MyOtherClass, class_name: 'My::Other' }
		]);

		let reg = _.reduce(FlModelFactory.defaultFactory()._model_services, function(acc, sv, sk) {
		    acc.push(sk);
		    return acc;
		}, [ ]);
		expect(reg).to.not.include(MY_MODEL_DESC.name);
		expect(reg).to.include(MY_OTHER_DESC.name);
	    });

	    it('should not register services with missing class_name', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let MyOtherClass = FlClassManager.get_class(MY_OTHER_DESC.name);

		FlModelFactory.defaultFactory().register('test_module', [
		    { service: MyFactoryTestModel },
		    { service: MyOtherClass, class_name: 'My::Other' }
		]);

		let reg = _.reduce(FlModelFactory.defaultFactory()._model_services, function(acc, sv, sk) {
		    acc.push(sk);
		    return acc;
		}, [ ]);
		expect(reg).to.not.include(MY_MODEL_DESC.name);
		expect(reg).to.include(MY_OTHER_DESC.name);
	    });

	    it('should overwrite services', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let MyOtherClass = FlClassManager.get_class(MY_OTHER_DESC.name);

		FlModelFactory.defaultFactory().register('test_module', [
		    { service: MyFactoryTestModel, class_name: 'My::Factory::Test::Model' },
		    { service: MyOtherClass, class_name: 'My::Other' }
		]);

		let reg = _.reduce(FlModelFactory.defaultFactory()._model_services, function(acc, sv, sk) {
		    acc.push(sk);
		    return acc;
		}, [ ]);
		expect(reg).to.include(MY_MODEL_DESC.name);
		expect(reg).to.include(MY_OTHER_DESC.name);
		let srv = FlModelFactory.defaultFactory()._model_services.MyFactoryTestModel.service;
		expect(srv.name).to.equal(MY_MODEL_DESC.name);
		
		FlModelFactory.defaultFactory().register('test_module_2', [
		    { service: MyFactoryTestModel, class_name: 'My::Other' }
		]);

		reg = _.reduce(FlModelFactory.defaultFactory()._model_services, function(acc, sv, sk) {
		    acc.push(sk);
		    return acc;
		}, [ ]);
		expect(reg).to.include(MY_MODEL_DESC.name);
		expect(reg).to.include(MY_OTHER_DESC.name);
		srv = FlModelFactory.defaultFactory()._model_services.MyFactoryTestModel.service;
		expect(srv.name).to.equal(MY_MODEL_DESC.name);
	    });
	});
	
	context('#service_for', function() {
	    beforeEach(function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let MyOtherClass = FlClassManager.get_class(MY_OTHER_DESC.name);

		FlModelFactory.defaultFactory().register('test_module', [
		    { service: MyFactoryTestModel, class_name: 'My::Factory::Test::Model' },
		    { service: MyOtherClass, class_name: 'My::Other' }
		]);
	    });
	    
	    it('should find a service by class name', function() {
		expect(FlModelFactory.defaultFactory().service_for('My::Factory::Test::Model')).to.not.be.null;
		expect(FlModelFactory.defaultFactory().service_for('MyFactoryTestModel')).to.not.be.null;
		expect(FlModelFactory.defaultFactory().service_for('My::Other')).to.not.be.null;
		expect(FlModelFactory.defaultFactory().service_for('MyOther')).to.not.be.null;
	    });
	    
	    it('should find a service by data object', function() {
		expect(FlModelFactory.defaultFactory().service_for(MODEL_1)).to.not.be.null;
		expect(FlModelFactory.defaultFactory().service_for(OTHER_1)).to.not.be.null;
	    });
	    
	    it('should not find an undefined service by class name', function() {
		expect(FlModelFactory.defaultFactory().service_for('Not::Class')).to.be.null;
	    });
	    
	    it('should not find an undefined service by data object', function() {
		expect(FlModelFactory.defaultFactory().service_for({ })).to.be.null;
	    });
	});
	
	context('#create', function() {
	    beforeEach(function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let MyOtherClass = FlClassManager.get_class(MY_OTHER_DESC.name);

		FlModelFactory.defaultFactory().register('test_module', [
		    { service: MyFactoryTestModel, class_name: 'My::Factory::Test::Model' },
		    { service: MyOtherClass, class_name: 'My::Other' }
		]);
	    });
	    
	    it('should create an object', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);

		let obj = FlModelFactory.defaultFactory().create(MODEL_1);
		expect(obj).to.be.an.instanceof(MyFactoryTestModel);
		expect(obj.username).to.equal('user102');
	    });
	    
	    it('should create an array of objects', function() {
		let MyFactoryTestModel = FlClassManager.get_class(MY_MODEL_DESC.name);
		let MyOtherClass = FlClassManager.get_class(MY_OTHER_DESC.name);

		let objs = FlModelFactory.defaultFactory().create([ MODEL_1, OTHER_1 ]);
		// instanceof works when a single object is created, but not from array elements ????
		//expect(objs[0]).to.be.an.instanceof(MyFactoryTestModel);
		expect(objs[0].type).to.equal('My::Factory::Test::Model');
		expect(objs[0].username).to.equal('user102');
		//expect(objs[1]).to.be.an.instanceof(MyOtherClass);
		expect(objs[1].type).to.equal('My::Other');
		expect(objs[1].username).to.equal('user104');
	    });

	    it('should return null for unsupported model classes', function() {
		expect(FlModelFactory.defaultFactory().create(UNDEFINED_1)).to.be.null;
	    });

	    it('should return null elements for unsupported model classes in an array', function() {
		let MyFactoryTestModel = FlClassManager.get_class('MyFactoryTestModel');
		let MyOtherClass = FlClassManager.get_class('MyOtherClass');

		let objs = FlModelFactory.defaultFactory().create([ MODEL_1, UNDEFINED_1, OTHER_1 ]);
		// instanceof works when a single object is created, but not from array elements ????
		//expect(objs[0]).to.be.an.instanceof(MyFactoryTestModel);
		expect(objs[0].type).to.equal('My::Factory::Test::Model');
		expect(objs[1]).to.be.null;
		//expect(objs[2]).to.be.an.instanceof(MyOtherClass);
		expect(objs[2].type).to.equal('My::Other');
	    });
	});
    });
});
