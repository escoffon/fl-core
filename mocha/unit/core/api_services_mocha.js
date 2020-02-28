const _ = require('lodash');
const chai = require('chai');
const { FlExtensions, FlClassManager } = require('fl/core/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/core/model_factory');
const {
    FlAPIService, FlNestedAPIService, FlAPIServiceRegistry, FlGlobalAPIServiceRegistry
} = require('fl/core/api_services');
const th = require('test_helpers');
const axios = require('axios');
const AxiosMockAdapter = require('axios-mock-adapter');

//const myaxios = axios.create();
const myaxios = axios;
const expect = chai.expect;

const MY_MODEL_DESC = {
    name: 'MyAPITestModel',
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

const MY_BASE_MODEL_DESC = {
    name: 'MyAPITestBaseModel',
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

const MY_OTHER_MODEL_DESC = {
    name: 'MyAPITestOtherModel',
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

const MY_MORE_MODEL_DESC = {
    name: 'MyAPITestMoreModel',
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
    type: "My::API::Test::Model",
    api_root: "/my/models",
    url_path: "my/models/1",
    fingerprint: "My::API::Test::Model/1",
    id: 1,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    value1: 'model1 - value1'
};

const MODEL_2 = {
    type: "My::API::Test::Model",
    api_root: "/my/models",
    url_path: "my/models/2",
    fingerprint: "My::API::Test::Model/2",
    id: 2,
    created_at: 'Thu, 13 Sep 2018 22:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2028 22:57:27 UTC +00:00',
    value1: 'model2 - value1'
};

const BASE_MODEL_10 = {
    type: "My::API::Test::BaseModel",
    api_root: "/my/base_models",
    url_path: "my/base_models/1",
    fingerprint: "My::API::Test::BaseModel/1",
    id: 10,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    value1: 'model1 - value1'
};

const OTHER_MODEL_20 = {
    type: "My::API::Test::OtherModel",
    api_root: "/my/other_models",
    url_path: "my/other_models/1",
    fingerprint: "My::API::Test::OtherModel/1",
    id: 20,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    value1: 'model1 - value1'
};

const MORE_MODEL_100 = {
    type: "My::API::Test::MoreModel",
    api_root: "/my/more_models",
    url_path: "my/More_models/100",
    fingerprint: "My::API::Test::MoreModel/100",
    id: 100,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    value1: 'more model100 - value1'
};

const MORE_MODEL_200 = {
    type: "My::API::Test::MoreModel",
    api_root: "/my/more_models",
    url_path: "my/More_models/100",
    fingerprint: "My::API::Test::MoreModel/200",
    id: 200,
    created_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    updated_at: 'Thu, 13 Sep 2018 21:57:27 UTC +00:00',
    value1: 'more model200 - value1'
};

const API_CFG = {
    root_url_template: '/my/models',
    namespace: 'my_model',
    data_names: [ 'model', 'models' ]
};

const NESTED_API_CFG = {
    root_url_template: '/my/bases/${base.id}/deps/${other.id}/more_models',
    namespace: 'more_model',
    data_names: [ 'more_model', 'more_models' ]
};

const SHALLOW_NESTED_API_CFG = {
    root_url_template: '/my/bases/${base.id}/deps/${other.id}/more_models',
    shallow_root_url_template: '/my/more_models',
    namespace: 'more_model',
    data_names: [ 'more_model', 'more_models' ]
};

const axmock = new AxiosMockAdapter(myaxios);

axmock
    .onGet('/my/models.json').reply(200, JSON.stringify({
	models: [ MODEL_1, MODEL_2 ],
	_pg: { _c: 2, _s:20 , _p: 2}
    }))

    .onGet('/my/models/1.json').reply(function(cfg) {
	rv = [ 200, JSON.stringify({ model: MODEL_1 }) ];

	// we do this to check that parameters are generated
	if (_.isObject(cfg.params)) rv.push(cfg.params);

	return rv;
    })

    .onGet('/my/models/10.json').reply(404, JSON.stringify({
	_error: { status: "not_found", message: "No user with id 10", details:null }
    }))

    .onPost('/my/models.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 200, JSON.stringify({ model: m }) ];
    })

    .onPatch('/my/models/1.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 200, JSON.stringify({ model: m }) ];
    })

    .onPatch('/my/models/10.json').reply(function(cfg) {
	let j = JSON.parse(cfg.data);
	let m = _.merge({}, MODEL_1, j.my_model);

	return [ 404, JSON.stringify({
	    _error: { status: "not_found", message: "No user with id 10", details:null }
	}) ];
    })

    .onGet('/my/bases/10/deps/20/more_models.json').reply(200, JSON.stringify({
	more_models: [ MORE_MODEL_100, MORE_MODEL_200 ],
	_pg: { _c: 2, _s:20 , _p: 2}
    }))

;

const MY_SERVICE_DESC = {
    name: 'MyAPIService',
    superclass: 'FlAPIService',
    initializer: function(srv_cfg) {
	this.__super_init('FlAPIService', API_CFG, srv_cfg);
    }
};

const MY_OTHER_SERVICE_DESC = {
    name: 'MyOtherAPIService',
    superclass: 'FlAPIService',
    initializer: function(base, other, srv_cfg) {
	this.__super_init('FlAPIService', NESTED_API_CFG, srv_cfg);
	this.base = base;
	this.other = other;
    }
};

const MY_NESTED_SERVICE_DESC = {
    name: 'MyNestedAPIService',
    superclass: 'FlNestedAPIService',
    initializer: function(base, other, srv_cfg) {
	this.__super_init('FlNestedAPIService', NESTED_API_CFG, srv_cfg);
	this.base = base;
	this.other = other;
    }
};

const MY_SHALLOW_NESTED_SERVICE_DESC = {
    name: 'MyShallowNestedAPIService',
    superclass: 'FlNestedAPIService',
    initializer: function(base, other, srv_cfg) {
	this.__super_init('FlNestedAPIService', SHALLOW_NESTED_API_CFG, srv_cfg);
	this.base = base;
	this.other = other;
    }
};

describe('fl.api_services module', function() {
    before(function() {
	let MyAPITestModel = FlClassManager.make_class(MY_MODEL_DESC);
	let MyAPITestBaseModel = FlClassManager.make_class(MY_BASE_MODEL_DESC);
	let MyAPITestOtherModel = FlClassManager.make_class(MY_OTHER_MODEL_DESC);
	let MyAPITestMoreModel = FlClassManager.make_class(MY_MORE_MODEL_DESC);

	FlGlobalModelFactory.register('api_services_tester', [
	    { service: MyAPITestModel, class_name: 'My::API::Test::Model' },
	    { service: MyAPITestBaseModel, class_name: 'My::API::Test::BaseModel' },
	    { service: MyAPITestOtherModel, class_name: 'My::API::Test::OtherModel' },
	    { service: MyAPITestMoreModel, class_name: 'My::API::Test::MoreModel' }
	]);

	let MyAPIService = FlClassManager.make_class(MY_SERVICE_DESC);
	let MyOtherAPIService = FlClassManager.make_class(MY_OTHER_SERVICE_DESC);
	let MyNestedAPIService = FlClassManager.make_class(MY_NESTED_SERVICE_DESC);
	let MyShallowNestedAPIService = FlClassManager.make_class(MY_SHALLOW_NESTED_SERVICE_DESC);
    });
    
    after(function() {
	th.clear_model_services(null, [ 'MyAPITestModel', 'MyAPITestBaseModel', 'MyAPITestOtherModel',
					'MyAPITestMoreModel' ]);
	th.clear_ext();
	th.clear_class([ 'MyAPITestModel', 'MyAPITestBaseModel', 'MyAPITestOtherModel', 'MyAPITestMoreModel',
			 'MyAPIService', 'MyOtherAPIService', 'MyNestedAPIService',
			 'MyShallowNestedAPIService' ]);
    });

    describe('FlAPIService', function() {
	context('default (global) configuration', function() {
	    it('should include the XSRF token names', function() {
		let cfg = FlAPIService.getServiceConfig();
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');
	    });

	    it('should merge values', function() {
		let orig = FlAPIService.getServiceConfig();
		expect(orig).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');

		FlAPIService.setServiceConfig({ c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		let cfg = FlAPIService.getServiceConfig();
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.xsrfHeaderName).to.eq(orig.xsrfHeaderName);
		expect(cfg.c1).to.eq('c1');
		
		FlAPIService.setServiceConfig(orig, true);
	    });

	    it('should replace values', function() {
		let orig = FlAPIService.getServiceConfig();

		FlAPIService.setServiceConfig({ c1: 'c1' }, true);
		let cfg = FlAPIService.getServiceConfig();
		expect(cfg).to.include.all.keys('c1');

		FlAPIService.setServiceConfig(orig, true);
	    });

	    it('should support config properties', function() {
		let orig = FlAPIService.getServiceConfig();

		expect(FlAPIService.xsrfCookieName).to.eq(orig.xsrfCookieName);
		FlAPIService.xsrfCookieName = 'NEW-NAME';
		expect(FlAPIService.xsrfCookieName).to.eq('NEW-NAME');

		expect(FlAPIService.xsrfHeaderName).to.eq(orig.xsrfHeaderName);
		FlAPIService.xsrfHeaderName = 'NEW-NAME';
		expect(FlAPIService.xsrfHeaderName).to.eq('NEW-NAME');

		expect(FlAPIService.xsrfToken).to.be.undefined;
		FlAPIService.xsrfToken = 'MY-TOKEN';
		expect(FlAPIService.xsrfToken).to.eq('MY-TOKEN');
		
		FlAPIService.setServiceConfig(orig, true);
	    });
	});
	
	context('service (local) configuration', function() {
	    it('should inherit from global defaults', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.getConfig()).to.include(FlAPIService.getServiceConfig());
	    });

	    it('should include the XSRF token names', function() {
		let srv = new FlAPIService(API_CFG);
		let cfg = srv.getConfig();
	       
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');
	    });

	    it('should include the XSRF token value', function() {
		let srv = new FlAPIService(API_CFG, { xsrfToken: 'MY-TOKEN' });
		let cfg = srv.getConfig();
	       
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg.xsrfToken).to.eq('MY-TOKEN');
	    });

	    it('should merge values in the constructor', function() {
		let srv = new FlAPIService(API_CFG, { c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		let cfg = srv.getConfig();

		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.xsrfHeaderName).to.eq(FlAPIService.getServiceConfig().xsrfHeaderName);
		expect(cfg.c1).to.eq('c1');
	    });

	    it('should merge values in the setter', function() {
		let srv = new FlAPIService(API_CFG);
		let cfg = srv.getConfig();

		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName');
		srv.setConfig({ c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		cfg = srv.getConfig();
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.xsrfHeaderName).to.eq(FlAPIService.getServiceConfig().xsrfHeaderName);
		expect(cfg.c1).to.eq('c1');
	    });

	    it('should replace values in the setter', function() {
		let srv = new FlAPIService(API_CFG, { c1: 'c1', xsrfCookieName: 'NEW_NAME' });
		let cfg = srv.getConfig();
	       
		expect(cfg).to.be.an.instanceof(Object);
		expect(cfg).to.include.all.keys('xsrfCookieName', 'xsrfHeaderName', 'c1');
		srv.setConfig({ c1: 'c1', xsrfCookieName: 'NEW_NAME' }, true);
		cfg = srv.getConfig();
		expect(cfg).to.include.all.keys('xsrfCookieName', 'c1');
		expect(cfg.xsrfCookieName).to.eq('NEW_NAME');
		expect(cfg.c1).to.eq('c1');
	    });

	    it('should support config properties', function() {
		let defs = FlAPIService.getServiceConfig();
		let srv = new FlAPIService(API_CFG);

		expect(srv.xsrfCookieName).to.eq(defs.xsrfCookieName);
		srv.xsrfCookieName = 'NEW-NAME';
		expect(srv.xsrfCookieName).to.eq('NEW-NAME');

		expect(srv.xsrfHeaderName).to.eq(defs.xsrfHeaderName);
		srv.xsrfHeaderName = 'NEW-NAME';
		expect(srv.xsrfHeaderName).to.eq('NEW-NAME');

		expect(srv.xsrfToken).to.be.undefined;
		srv.xsrfToken = 'MY-TOKEN';
		expect(srv.xsrfToken).to.eq('MY-TOKEN');
	    });

	    it.skip('should support custom base URLs in the constructor', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let baseURL = 'http://www.server.com:8080';
		let srv = new FlAPIService(API_CFG, { baseURL: baseURL });
		
		return srv.show(1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.value1).to.eq('model1 - value1');
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));

			return Promise.resolve(true);
		    });
	    });
	});

	context('._wrap_data', function() {
	    it('should process :wrapped and :unwrapped', function() {
		let FlAPIService = FlClassManager.get_class('FlAPIService');
		let srv = new FlAPIService(API_CFG);

		let wrapped = {
		    w1: 10,
		    w2: { a1: 110, a2: 120 }
		};
		let unwrapped = {
		    u1: 20,
		    u2: { a1: 210, a2: { a3: 230 } }
		};
		let data = srv._wrap_data({ wrapped: wrapped, unwrapped: unwrapped });
		expect(data).to.have.keys('my_model', 'u1', 'u2');
		expect(data.my_model).to.include(wrapped);
		expect(data.u1).to.eql(20);
		expect(data.u2).to.have.keys('a1', 'a2');
		expect(data.u2.a1).to.eql(210);
		expect(data.u2.a2).to.include(unwrapped.u2.a2);
	    });

	    it('should process :wrapped alone', function() {
		let FlAPIService = FlClassManager.get_class('FlAPIService');
		let srv = new FlAPIService(API_CFG);

		let wrapped = {
		    w1: 10,
		    w2: { a1: 110, a2: 120 }
		};
		let data = srv._wrap_data({ wrapped: wrapped });
		expect(data).to.have.keys('my_model');
		expect(data.my_model).to.include(wrapped);
	    });

	    it('should process :unwrapped alone', function() {
		let FlAPIService = FlClassManager.get_class('FlAPIService');
		let srv = new FlAPIService(API_CFG);

		let unwrapped = {
		    u1: 20,
		    u2: { a1: 210, a2: { a3: 230 } }
		};
		let data = srv._wrap_data({ unwrapped: unwrapped });
		expect(data).to.have.keys('u1', 'u2');
		expect(data.u1).to.eql(20);
		expect(data.u2).to.have.keys('a1', 'a2');
		expect(data.u2.a1).to.eql(210);
		expect(data.u2.a2).to.include(unwrapped.u2.a2);
	    });

	    it('should not wrap :wrapped if namespace is undefined', function() {
		let FlAPIService = FlClassManager.get_class('FlAPIService');
		let srv = new FlAPIService({
		    root_url_template: '/my/models',
		    data_names: [ 'model', 'models' ]
		});

		let wrapped = {
		    w1: 10,
		    w2: { a1: 110, a2: 120 }
		};
		let unwrapped = {
		    u1: 20,
		    u2: { a1: 210, a2: { a3: 230 } }
		};
		let data = srv._wrap_data({ wrapped: wrapped, unwrapped: unwrapped });
		expect(data).to.have.keys('w1', 'w2', 'u1', 'u2');
		expect(data.w1).to.eql(10);
		expect(data.w2).to.have.keys('a1', 'a2');
		expect(data.w2.a1).to.eql(110);
		expect(data.w2.a2).to.eql(120);
		expect(data.u1).to.eql(20);
		expect(data.u2).to.have.keys('a1', 'a2');
		expect(data.u2.a1).to.eql(210);
		expect(data.u2.a2).to.include(unwrapped.u2.a2);
	    });
	});
	
	context('.url_path_for', function() {
	    context('for action :index', function() {
		it('should be correct when no replacement instructions are present', function() {
		    let MyAPIService = FlClassManager.get_class('MyAPIService');
		    let srv = new MyAPIService();

		    expect(srv.url_path_for('index')).to.eql('/my/models.json');
		});

		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);

		    let MyOtherAPIService = FlClassManager.get_class('MyOtherAPIService');
		    let srv = new MyOtherAPIService(my_base, my_other);
		    expect(srv.url_path_for('index')).to.eql('/my/bases/10/deps/20/more_models.json');
		});
	    });

	    context('for action :create', function() {
		it('should be correct when no replacement instructions are present', function() {
		    let MyAPIService = FlClassManager.get_class('MyAPIService');
		    let srv = new MyAPIService();

		    expect(srv.url_path_for('create')).to.eql('/my/models.json');
		});

		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);

		    let MyOtherAPIService = FlClassManager.get_class('MyOtherAPIService');
		    let srv = new MyOtherAPIService(my_base, my_other);
		    expect(srv.url_path_for('create')).to.eql('/my/bases/10/deps/20/more_models.json');
		});
	    });

	    context('for action :show', function() {
		it('should be correct when no replacement instructions are present', function() {
		    let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		    let my1 = new MyAPITestModel(MODEL_1);
		    let MyAPIService = FlClassManager.get_class('MyAPIService');
		    let srv = new MyAPIService();

		    expect(srv.url_path_for('show', my1)).to.eql('/my/models/1.json');
		    expect(srv.url_path_for('show', 1234)).to.eql('/my/models/1234.json');
		});

		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);
		    
		    let MyOtherAPIService = FlClassManager.get_class('MyOtherAPIService');
		    let srv = new MyOtherAPIService(my_base, my_other);
		    expect(srv.url_path_for('show', my1)).to.eql('/my/bases/10/deps/20/more_models/100.json');
		    expect(srv.url_path_for('show', 1234)).to.eql('/my/bases/10/deps/20/more_models/1234.json');
		});
	    });

	    context('for action :update', function() {
		it('should be correct when no replacement instructions are present', function() {
		    let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		    let my1 = new MyAPITestModel(MODEL_1);
		    let MyAPIService = FlClassManager.get_class('MyAPIService');
		    let srv = new MyAPIService();

		    expect(srv.url_path_for('update', my1)).to.eql('/my/models/1.json');
		    expect(srv.url_path_for('update', 1234)).to.eql('/my/models/1234.json');
		});

		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);

		    let MyOtherAPIService = FlClassManager.get_class('MyOtherAPIService');
		    let srv = new MyOtherAPIService(my_base, my_other);
		    expect(srv.url_path_for('update', my1)).to.eql('/my/bases/10/deps/20/more_models/100.json');
		    expect(srv.url_path_for('update', 1234)).to.eql('/my/bases/10/deps/20/more_models/1234.json');
		});
	    });

	    context('for action :destroy', function() {
		it('should be correct when no replacement instructions are present', function() {
		    let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		    let my1 = new MyAPITestModel(MODEL_1);
		    let MyAPIService = FlClassManager.get_class('MyAPIService');
		    let srv = new MyAPIService();

		    expect(srv.url_path_for('destroy', my1)).to.eql('/my/models/1.json');
		    expect(srv.url_path_for('destroy', 1234)).to.eql('/my/models/1234.json');
		});

		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);
		    
		    let MyOtherAPIService = FlClassManager.get_class('MyOtherAPIService');
		    let srv = new MyOtherAPIService(my_base, my_other);
		    expect(srv.url_path_for('destroy', my1)).to.eql('/my/bases/10/deps/20/more_models/100.json');
		    expect(srv.url_path_for('destroy', 1234)).to.eql('/my/bases/10/deps/20/more_models/1234.json');
		});
	    });

	    context('for an unsupported action', function() {
		it('should return null when no replacement instructions are present', function() {
		    let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		    let my1 = new MyAPITestModel(MODEL_1);
		    let MyAPIService = FlClassManager.get_class('MyAPIService');
		    let srv = new MyAPIService();

		    expect(srv.url_path_for('unknown', my1)).to.be.null;
		    expect(srv.url_path_for('unknown', 1234)).to.be.null;
		});

		it('should return null with replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);

		    let MyOtherAPIService = FlClassManager.get_class('MyOtherAPIService');
		    let srv = new MyOtherAPIService(my_base, my_other);
		    expect(srv.url_path_for('unknown', my1)).to.be.null;
		    expect(srv.url_path_for('unknown', 1234)).to.be.null;
		});
	    });
	});
	
	context(':index (simple resource)', function() {
	    it('should return objects', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);

		return srv.index()
		    .then(function(data) {
			expect(data).to.be.an('array');
			expect(data.length).to.eq(2);
			expect(data[0]).to.be.an.instanceof(MyAPITestModel);
			expect(data[0].value1).to.eq('model1 - value1');
			expect(data[1]).to.be.an.instanceof(MyAPITestModel);
			expect(data[1].value1).to.eq('model2 - value1');
			return Promise.resolve(true);
		    })
		    .catch(function(xx) {
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index()
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index(null, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let baseURL = 'http://www.server.com:8080';
		let srv = new FlAPIService(API_CFG);

		return srv.index({ }, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.index()
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});
	
	context(':index (nested resource)', function() {
	    it('should return objects', function() {
		let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		let MyNestedAPIService = FlClassManager.get_class('MyNestedAPIService');
		let srv = new MyNestedAPIService(my_base, my_other, NESTED_API_CFG);

		return srv.index()
		    .then(function(data) {
			expect(data).to.be.an('array');
			expect(data.length).to.eq(2);
			expect(data[0]).to.be.an.instanceof(MyAPITestMoreModel);
			expect(data[0].value1).to.eq('more model100 - value1');
			expect(data[1]).to.be.an.instanceof(MyAPITestMoreModel);
			expect(data[1].value1).to.eq('more model200 - value1');
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index()
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index(null, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let baseURL = 'http://www.server.com:8080';
		let srv = new FlAPIService(API_CFG);

		return srv.index({ }, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.index()
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':show', function() {
	    it('should return a known object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.show(1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);
		let my1 = new MyAPITestModel(MODEL_1);

		// this confirms that a new instance is not created
		
		my1.test_tag = 'TEST';
		
		return srv.show(my1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.value1).to.eq('model1 - value1');
			expect(data.test_tag).to.eql('TEST');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.show(10)
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(r) {
			expect(r.response.status).to.eq(404);
			let err = srv.response_error(r);
			expect(err.status).to.eq('not_found');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.show(1)
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });
		let params = { param: 'value' };

		return srv.show(1, params, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let baseURL = 'http://www.server.com:8080';
		let srv = new FlAPIService(API_CFG);

		return srv.show(1, null, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.show(1)
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.show(10)
		    .catch(function(r) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':create', function() {
	    it('should return a new object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ wrapped: { value1: 'new value1' } },
				  { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let baseURL = 'http://www.server.com:8080';
		let srv = new FlAPIService(API_CFG);

		return srv.create({ wrapped: { value1: 'new value1' } }, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfToken: 'MY-TOKEN' });
		
		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':update', function() {
	    it('should return the edited object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);
		let my1 = new MyAPITestModel(MODEL_1);
		
		// this confirms that a new instance is not created
		
		my1.test_tag = 'TEST';
		
		return srv.update(my1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');
			expect(data.test_tag).to.eql('TEST');

			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG);
		
		return srv.update(10, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(r) {
			expect(r.response.status).to.eq(404);
			let err = srv.response_error(r);
			expect(err.status).to.eq('not_found');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { wrapped: { value1: 'new value1' } },
				  { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let baseURL = 'http://www.server.com:8080';
		let srv = new FlAPIService(API_CFG);

		return srv.update(1, { wrapped: { value1: 'new value1' } }, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let srv = new FlAPIService(API_CFG, { xsrfToken: 'MY-TOKEN' });
		
		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let srv = new FlAPIService(API_CFG);

		expect(srv.response).to.be.undefined;
		
		return srv.update(10, { wrapped: { value1: 'new value1' } })
		    .catch(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context('response_error', function() {
	    it('should extract standard API data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({
		    response: {
			status: 'test_status',
			data: {
			    _error: {
				status: 'error_status',
				message: 'error_message',
				details: 'error_details'
			    }
			}
		    }
		});

		expect(err).to.include({
		    status: 'error_status', message: 'error_message', details: 'error_details'
		});
	    });

	    it('should extract (almost) standard API data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({
		    response: {
			data: {
			    _error: {
				status: 'error_status',
				message: 'error_message',
				details: 'error_details'
			    }
			}
		    }
		});

		expect(err).to.include({
		    status: 'error_status', message: 'error_message', details: 'error_details'
		});
	    });

	    it('should extract with missing data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({
		    response: { status: 'test_status', message: 'test_message' }
		});

		expect(err).to.include({
		    status: 'test_status', message: 'test_message'
		});
	    });

	    it('should extract with incomplete data', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({
		    response: { status: 'test_status', message: 'test_message', data: { }}
		});

		expect(err).to.include({
		    status: 'test_status', message: 'test_message'
		});
	    });

	    it('should extract with correct priorities', function() {
		let srv = new FlAPIService(API_CFG);
		let err = srv.response_error({
		    response: {
			status: 'test_status',
			message: 'test_message',
			data: {
			    _error: {
				status: 'error_status',
				message: 'error_message',
				details: 'error_details'
			    }
			}
		    }
		});

		expect(err).to.include({
		    status: 'error_status', message: 'error_message', details: 'error_details'
		});
	    });
	});
    });

    describe('FlAPIService subclass', function() {
	context(':index', function() {
	    it('should return objects', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.index()
		    .then(function(data) {
			expect(data).to.be.an('array');
			expect(data.length).to.eq(2);
			expect(data[0]).to.be.an.instanceof(MyAPITestModel);
			expect(data[0].value1).to.eq('model1 - value1');
			expect(data[1]).to.be.an.instanceof(MyAPITestModel);
			expect(data[1].value1).to.eq('model2 - value1');
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index()
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.index(null, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		let baseURL = 'http://www.server.com:8080';

		return srv.index(null, { baseURL : baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.index()
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':show', function() {
	    it('should return a known object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.show(1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.value1).to.eq('model1 - value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		let my1 = new MyAPITestModel(MODEL_1);
		
		// this confirms that a new instance is not created
		
		my1.test_tag = 'TEST';
		
		return srv.show(my1)
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.value1).to.eq('model1 - value1');
			expect(data.test_tag).to.eql('TEST');

			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.show(10)
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(e) {
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.show(1)
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });
		let params = { param: 'value' };

		return srv.show(1, params, { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			expect(r.headers).to.include(params);
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });
		let params = { param: 'value' };
		let baseURL = 'http://www.server.com:8080';

		return srv.show(1, params, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.show(1)
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.show(10)
		    .catch(function(r) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':create', function() {
	    it('should return a new object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.create({ wrapped: { value1: 'new value1' } },
				  { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });
		let baseURL = 'http://www.server.com:8080';

		return srv.create({ wrapped: { value1: 'new value1' } }, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfHeaderName: 'NEW-HEADER-NAME', xsrfToken: 'MY-TOKEN' });
		
		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.create({ wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});

	context(':update', function() {
	    it('should return the edited object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');

			return Promise.resolve(true);
		    });
	    });

	    it('should accept a model instance', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		let my1 = new MyAPITestModel(MODEL_1);
		
		// this confirms that a new instance is not created
		
		my1.test_tag = 'TEST';
		
		return srv.update(my1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(data).to.be.an.instanceof(MyAPITestModel);
			expect(data.id).to.eq(1);
			expect(data.value1).to.eq('new value1');
			expect(data.test_tag).to.eql('TEST');

			return Promise.resolve(true);
		    });
	    });

	    it('should error on an unknown object', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();
		
		return srv.update(10, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			return Promise.reject('should not have reached this');
		    })
		    .catch(function(r) {
			expect(r.response.status).to.eq(404);
			let err = srv.response_error(r);
			expect(err.status).to.eq('not_found');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the local configuration', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('NEW-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it('should pick up the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });

		return srv.update(1, { wrapped: { value1: 'new value1' } },
				  { xsrfCookieName: 'YET-COOKIE-NAME' })
		    .then(function(data) {
			let r = srv.response;

			expect(r.config.xsrfCookieName).to.eq('YET-COOKIE-NAME');
			
			return Promise.resolve(true);
		    });
	    });

	    it.skip('should support custom base URLs in the configuration argument', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfCookieName: 'NEW-COOKIE-NAME' });
		let baseURL = 'http://www.server.com:8080';

		return srv.update(1, { wrapped: { value1: 'new value1' } }, { baseURL: baseURL })
		    .then(function(data) {
			expect(srv.response.config.baseURL).to.eql(baseURL);
			expect(srv.response.config.url).to.match(new RegExp(`^${baseURL}`));
			
			return Promise.resolve(true);
		    });
	    });

	    it('should add the XSRF header', function() {
		let MyAPITestModel = FlClassManager.get_class('MyAPITestModel');
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService({ xsrfHeaderName: 'NEW-HEADER-NAME', xsrfToken: 'MY-TOKEN' });
		
		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			let r = srv.response;
			expect(r.config.headers).to.include({ [srv.xsrfHeaderName]: 'MY-TOKEN' });
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on success', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.update(1, { wrapped: { value1: 'new value1' } })
		    .then(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });

	    it('should set response on error', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		let srv = new MyAPIService();

		expect(srv.response).to.be.undefined;
		
		return srv.update(10, { wrapped: { value1: 'new value1' } })
		    .catch(function(data) {
			expect(srv.response).to.be.an.instanceof(Object);
			expect(srv.response).to.have.keys('status', 'data', 'headers', 'config');
			return Promise.resolve(true);
		    });
	    });
	});
    });

    describe('FlNestedAPIService', function() {
	context('.url_path_for', function() {
	    context('for action :index', function() {
		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);

		    let MyNestedAPIService = FlClassManager.get_class('MyNestedAPIService');
		    let srv = new MyNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('index')).to.eql('/my/bases/10/deps/20/more_models.json');

		    let MyShallowNestedAPIService = FlClassManager.get_class('MyShallowNestedAPIService');
		    srv = new MyShallowNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('index')).to.eql('/my/bases/10/deps/20/more_models.json');
		});
	    });

	    context('for action :create', function() {
		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);

		    let MyNestedAPIService = FlClassManager.get_class('MyNestedAPIService');
		    let srv = new MyNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('create')).to.eql('/my/bases/10/deps/20/more_models.json');

		    let MyShallowNestedAPIService = FlClassManager.get_class('MyShallowNestedAPIService');
		    srv = new MyShallowNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('create')).to.eql('/my/bases/10/deps/20/more_models.json');
		});
	    });

	    context('for action :show', function() {
		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);
		    
		    let MyNestedAPIService = FlClassManager.get_class('MyNestedAPIService');
		    let srv = new MyNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('show', my1)).to.eql('/my/bases/10/deps/20/more_models/100.json');
		    expect(srv.url_path_for('show', 1234)).to.eql('/my/bases/10/deps/20/more_models/1234.json');

		    let MyShallowNestedAPIService = FlClassManager.get_class('MyShallowNestedAPIService');
		    srv = new MyShallowNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('show', my1)).to.eql('/my/more_models/100.json');
		    expect(srv.url_path_for('show', 1234)).to.eql('/my/more_models/1234.json');
		});
	    });

	    context('for action :update', function() {
		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);

		    let MyNestedAPIService = FlClassManager.get_class('MyNestedAPIService');
		    let srv = new MyNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('update', my1)).to.eql('/my/bases/10/deps/20/more_models/100.json');
		    expect(srv.url_path_for('update', 1234)).to.eql('/my/bases/10/deps/20/more_models/1234.json');

		    let MyShallowNestedAPIService = FlClassManager.get_class('MyShallowNestedAPIService');
		    srv = new MyShallowNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('update', my1)).to.eql('/my/more_models/100.json');
		    expect(srv.url_path_for('update', 1234)).to.eql('/my/more_models/1234.json');
		});
	    });

	    context('for action :destroy', function() {
		it('should expand replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);
		    
		    let MyNestedAPIService = FlClassManager.get_class('MyNestedAPIService');
		    let srv = new MyNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('destroy', my1)).to.eql('/my/bases/10/deps/20/more_models/100.json');
		    expect(srv.url_path_for('destroy', 1234)).to.eql('/my/bases/10/deps/20/more_models/1234.json');

		    let MyShallowNestedAPIService = FlClassManager.get_class('MyShallowNestedAPIService');
		    srv = new MyShallowNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('destroy', my1)).to.eql('/my/more_models/100.json');
		    expect(srv.url_path_for('destroy', 1234)).to.eql('/my/more_models/1234.json');
		});
	    });

	    context('for an unsupported action', function() {
		it('should return null with replacement instructions', function() {
		    let MyAPITestBaseModel = FlClassManager.get_class('MyAPITestBaseModel');
		    let MyAPITestOtherModel = FlClassManager.get_class('MyAPITestOtherModel');
		    let my_base = new MyAPITestBaseModel(BASE_MODEL_10);
		    let my_other = new MyAPITestOtherModel(OTHER_MODEL_20);
		    let MyAPITestMoreModel = FlClassManager.get_class('MyAPITestMoreModel');
		    let my1 = new MyAPITestMoreModel(MORE_MODEL_100);

		    let MyNestedAPIService = FlClassManager.get_class('MyNestedAPIService');
		    let srv = new MyNestedAPIService(my_base, my_other, NESTED_API_CFG);

		    expect(srv.url_path_for('unknown', my1)).to.be.null;
		    expect(srv.url_path_for('unknown', 1234)).to.be.null;

		    let MyShallowNestedAPIService = FlClassManager.get_class('MyShallowNestedAPIService');
		    srv = new MyShallowNestedAPIService(my_base, my_other);
		    expect(srv.url_path_for('unknown', my1)).to.be.null;
		    expect(srv.url_path_for('unknown', 1234)).to.be.null;
		});
	    });
	});
    });
    
    describe('FlAPIServiceRegistry', function() {
	afterEach(function() {
	    th.clear_api_services(null, [ 'MyOtherAPIService', 'MyOther2APIService' ]);
	});
	
	context('#register', function() {
	    it('should register a service', function() {
		expect(FlGlobalAPIServiceRegistry.service_info('My::Other')).to.be.null;
		expect(FlGlobalAPIServiceRegistry.service_info('MyOther')).to.be.null;
	    
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOtherAPIService: 'My::Other'
		});

		expect(FlGlobalAPIServiceRegistry.service_info('My::Other')).to.not.be.null;
		expect(FlGlobalAPIServiceRegistry.service_info('MyOther')).to.not.be.null;
	    });

	    it('should override a registered service', function() {
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOtherAPIService: 'My::Other'
		});

		let info = FlGlobalAPIServiceRegistry.service_info('My::Other');
		expect(info).to.be.an.instanceof(Object);
		expect(info.api_service).to.eq('MyOtherAPIService');
		
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOther2APIService: 'My::Other'
		});
		info = FlGlobalAPIServiceRegistry.service_info('My::Other');
		expect(info).to.be.an.instanceof(Object);
		expect(info.api_service).to.eq('MyOther2APIService');
	    });
	});
	
	context('#service_info', function() {
	    it('should find a registered service', function() {
		FlGlobalAPIServiceRegistry.register('test_model', {
		    MyOtherAPIService: 'My::Other'
		});

		expect(FlGlobalAPIServiceRegistry.service_info('My::Other')).to.not.be.null;
		expect(FlGlobalAPIServiceRegistry.service_info('MyOther')).to.not.be.null;
	    });

	    it('should return null for an unregistered service', function() {
		expect(FlGlobalAPIServiceRegistry.service_info('My::Not::Registered')).to.be.null;
	    });
	});
	
	context('#create', function() {
	    it('should create a registered service', function() {
		let MyAPIService = FlClassManager.get_class('MyAPIService');
		expect(MyAPIService).to.not.be.undefined;
		
		FlGlobalAPIServiceRegistry.register('api_services_tester', {
		    'MyAPIService': 'My::API::Test::Model'
		});

		let srv = FlGlobalAPIServiceRegistry.create('My::API::Test::Model', { prop1: 1 });
		expect(srv).to.be.an.instanceof(MyAPIService);
		expect(srv._srv_cfg.prop1).to.eq(1);

		srv = FlGlobalAPIServiceRegistry.create('My::API::Test::Model', { prop1: 2 });
		expect(srv).to.be.an.instanceof(MyAPIService);
		expect(srv._srv_cfg.prop1).to.eq(2);
	    });

	    it('should return null for an unregistered service', function() {
		expect(FlGlobalAPIServiceRegistry.create('Not::Registered', { prop1: 1 })).to.be.null;
	    });
	});
    });
});
