const _ = require('lodash');
const chai = require('chai');
const { FlExtensions, FlClassManager } = require('fl/core/object_system');
const th = require('test_helpers');

const expect = chai.expect;

const EXT1 = {
    name: 'Ext1',
    desc: {
	methods: {
	    f1: function(s) { return 'f1: ' + s; }
	}
    }
};

const EXT2 = {
    name: 'Ext2',
    desc: {
	methods: {
	    f1: function(s) { return 'f10: ' + s; },
	    f2: function(s) { return 'f20: ' + s; }
	}
    }
};

const EXT3 = {
    name: 'Ext3',
    desc: {
	class_methods: {
	    c1: function(s) { return 'c100: ' + s; }
	},
	instance_methods: {
	    f1: function(s) { return 'f100: ' + s; },
	    f2: function(s) { return 'f200: ' + s; }
	}
    }
};

const EXT_WITH_INIT = {
    name: 'ExtWithInit',
    desc: {
	methods: {
	    f1: function(s) { return 'f10: ' + s; },
	    f2: function(s) { return 'f20: ' + s; },
	    passes: function() { return this._passes; }
	},
	initializer: function(pass) {
	    if (pass == 'pre') this._passes = [ ];
	    this._passes.push('pass1: ' + pass);
	}
    }
};

const EXT_ONLY_INIT = {
    name: 'ExtOnlyInit',
    desc: {
	initializer: function(pass) {
	    if (pass == 'pre') this._passes = [ ];
	    this._passes.push('pass2: ' + pass);
	}
    }
};

const EXT_FUNCTION_METHODS = {
    name: 'ExtFunctionMethods',
    desc: {
	methods: function() {
	    this.c4 = function(s) { return 'c4: ' + s; };
	    this.prototype.f4 = function(s) { return 'f4: ' + s; };
	},
	initializer: function(pass) {
	    if (pass == 'pre') this._passes = [ ];
	    this._passes.push('pass3: ' + pass);
	}
    }
};

const MY_BASE_DESC = {
    name: 'MyBase',
    initializer: function(a1, a2) {
	this.__super_init('FlRoot');
	this._a1 = a1;
	this._a2 = a2;
	this._ctx = { };
    },
    instance_methods: {
	set_msg: function(msg) {
	    this._ctx.msg = msg;
	},
	ctx: function() {
	    return this._ctx;
	}
    },
    class_properties: {
	c1: { get: function() { return (_.isUndefined(this._c1)) ? 'c1' : this._c1; } },
	c2: {
	    get: function() { return (_.isUndefined(this._c2)) ? 'c2' : this._c2; },
	    set: function(v) { this._c2 = v; }
	}
    },
    instance_properties: {
	a1: { get: function() { return this._a1; } },
	a2: {
	    get: function() { return this._a2; },
	    set: function(v) { this._a2 = v; }
	}
    }
};

const MY_CLASS_DESC = {
    name: 'MyClass',
    superclass: 'MyBase',
    initializer: function(a1) {
	this.__super_init('MyBase', a1, 'MyClass - a2');
    },
    instance_methods: {
	set_msg: function(msg) {
	    this.__super('MyBase', 'set_msg', msg + ' - MyClass');
	},
	my_method: function(msg) {
	    this._ctx.msg = msg;
	}
    }
};

const MY_CLASS1_DESC = {
    name: 'MyClass1',
    superclass: 'MyBase',
    initializer: function(a1) {
	this.__super_init('MyBase', a1, 'MyClass1 - a2');
    },
    instance_methods: {
	set_msg: function(msg) {
	    this.__super('MyBase', 'set_msg', msg + ' - MyClass1');
	},
	my_method: function(msg) {
	    this._ctx.msg = msg;
	}
    },
    extensions: [ EXT_WITH_INIT.name ]
};

const MY_CLASS2_DESC = {
    name: 'MyClass2',
    superclass: 'MyBase',
    initializer: function(a1) {
	this.__super_init('MyBase', a1, 'MyClass2 - a2');
    },
    instance_methods: {
	set_msg: function(msg) {
	    this.__super('MyBase', 'set_msg', msg + ' - MyClass2');
	},
	my_method: function(msg) {
	    this._ctx.msg = msg;
	}
    },
    extensions: [ EXT_FUNCTION_METHODS.name ]
};

const MY_MODEL_BASE = {
    name: 'MyModelBase',
    initializer: function(data) {
	this.__super_init('FlRoot');
	this.refresh(data);
    },
    instance_methods: {
	refresh: function(data) {
	    if (_.isObject(data))
	    {
		let self = this;
		
		_.forEach(data, function(dv, dk) {
		    self[dk] = dv;
		});
	    }
	}
    }
};

const MY_MODEL_CLASS = {
    name: 'MyModelClass',
    superclass: 'MyModelBase',
    initializer: function(data) {
	this.__super_init('MyModelBase', data);
    },
    instance_methods: {
	refresh: function(data) {
	    this.__super('MyModelBase', 'refresh', data);

	    if (_.isObject(data) && _.isString(data.doubler))
	    {
		this.doubler = data.doubler + ' - ' + data.doubler;
	    }
	}
    }
};
    
describe('fl.object_system module', function() {
    describe('FlExtensions', function() {
	afterEach(function() {
	    th.clear_ext([ EXT1.name, EXT2.name, EXT3.name, EXT_WITH_INIT.name, EXT_ONLY_INIT.name, 
			   EXT_FUNCTION_METHODS.name ]);
	});
	
	context('named', function() {
	    it('should register an extension', function() {
		let x = FlExtensions.named(EXT1.name, EXT1.desc);
		expect(x.methods.f1('a')).to.equal('f1: a');
	    });

	    it('should throw on duplicate registration', function() {
		let x = FlExtensions.named(EXT1.name, EXT1.desc);
		expect(x.methods.f1('a')).to.equal('f1: a');
		expect(function() { FlExtensions.named('Ext1', EXT2); }).to.throw();
	    });

	    it('should overwrite on duplicate registration if instructed', function() {
		let x = FlExtensions.named(EXT1.name, EXT1.desc);
		expect(x.methods.f1('a')).to.equal('f1: a');
		expect(function() { FlExtensions.named(EXT1.name, EXT2.desc, true); }).to.not.throw();
		let y = FlExtensions.lookup(EXT1.name);
		expect(y.methods.f1('a')).to.equal('f10: a');
		expect(y.methods.f2('a')).to.equal('f20: a');
	    });
	});

	context('list', function() {
	    it('should list names', function() {
		let e1 = FlExtensions.named(EXT1.name, EXT1.desc);
		let e2 = FlExtensions.named(EXT2.name, EXT2.desc);

		expect(FlExtensions.list()).to.have.members([ EXT1.name, EXT2.name ]);
	    });

	    it('should list descriptors', function() {
		let e1 = FlExtensions.named(EXT1.name, EXT1.desc);
		let e2 = FlExtensions.named(EXT2.name, EXT2.desc);
		let el = FlExtensions.list(true);

		let x = _.map(el, function(e) { return _.isObject(e) && _.isString(e.name); });
		expect(x).to.have.members([ true, true ]);
		
		x = _.map(el, function(e) { return e.name; });
		expect(x).to.have.members([ EXT1.name, EXT2.name ]);
	    });
	});
	
	context('lookup', function() {
	    it('should find a registered extension by name', function() {
		let x = FlExtensions.named(EXT1.name, EXT1.desc);
		let y = FlExtensions.lookup(EXT1.name);
		expect(y.methods.f1('a')).to.equal(x.methods.f1('a'));
	    });

	    it('should throw on an unregistered extension by name', function() {
		expect(function() { return FlExtensions.lookup('NoExt'); }).to.throw();
	    });

	    it('should return an unregistered extension by descriptor', function() {
		expect(FlExtensions.lookup(EXT1.desc).methods.f1('a')).to.equal('f1: a');
		expect(FlExtensions.lookup(EXT2.desc).methods.f2('a')).to.equal('f20: a');
		expect(function() { return FlExtensions.lookup(EXT_ONLY_INIT.desc); }).to.not.throw();
		expect(function() { return FlExtensions.lookup(EXT_FUNCTION_METHODS.desc); }).to.not.throw();
	    });

	    it('should return undefined on an unregistered extension by name if instructed', function() {
		expect(FlExtensions.lookup('NoExt', false)).to.be.undefined;
	    });

	    it('should throw on an unregistered extension by bad descriptor', function() {
		expect(function() { return FlExtensions.lookup({ }); }).to.throw();
	    });
	});

	context('register', function() {
	    it('should inject a simple extension by name', function() {
		let x = FlExtensions.named(EXT1.name, EXT1.desc);

		let ctor = function() { };
		let p = FlExtensions.register(EXT1.name, ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f1: a');
	    });

	    it('should inject a simple extension by descriptor', function() {
		let ctor = function() { };
		let p = FlExtensions.register(EXT2.desc, ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f10: a');
	    });

	    it('should inject class and instance methods', function() {
		let x = FlExtensions.named(EXT3.name, EXT3.desc);

		let ctor = function() { };
		let p = FlExtensions.register(EXT3.name, ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f100: a');
		expect(f.f2('a')).to.equal('f200: a');
		expect(function() { return f.c1('a'); }).to.throw();
		expect(ctor.c1('a')).to.equal('c100: a');
	    });

	    it('should inject a function methods extension by name', function() {
		let x = FlExtensions.named(EXT_FUNCTION_METHODS.name, EXT_FUNCTION_METHODS.desc);

		let ctor = function() { };
		let p = FlExtensions.register(EXT_FUNCTION_METHODS.name, ctor);
		let f = new ctor();
		expect(f.f4('a')).to.equal('f4: a');
		expect(function() { return f.c4('a'); }).to.throw();
		expect(ctor.c4('a')).to.equal('c4: a');
	    });

	    it('should inject a function methods extension by descriptor', function() {
		let ctor = function() { };
		let p = FlExtensions.register(EXT_FUNCTION_METHODS.desc, ctor);
		let f = new ctor();
		expect(f.f4('a')).to.equal('f4: a');
		expect(function() { return f.c4('a'); }).to.throw();
		expect(ctor.c4('a')).to.equal('c4: a');
	    });
	    
	    it('should no-op an undefined extension', function() {
		expect(function() { FlExtensions.register('NoExt', { }); }).to.not.throw();
	    });
	});

	context('initialize', function() {
	    it('should no-op an extension without initializer ', function() {
		let x = FlExtensions.named(EXT1.name, EXT1.desc);

		expect(function() { FlExtensions.initialize(EXT1.name, { }, 'pre'); }).to.not.throw();
		expect(function() { FlExtensions.initialize(x, { }, 'pre'); }).to.not.throw();
	    });

	    it('should no-op an unknown extension ', function() {
		expect(function() { FlExtensions.initialize('NoExt', { }, 'pre'); }).to.not.throw();
	    });

	    it('should execute for an extension with initializer', function() {
		let x = FlExtensions.named(EXT_WITH_INIT.name, EXT_WITH_INIT.desc);

		let ctor = function() { };
		let p = FlExtensions.register(EXT_WITH_INIT.name, ctor);
		let f = new ctor();
		expect(f.f1('a')).to.equal('f10: a');
		expect(function() { FlExtensions.initialize(EXT_WITH_INIT.name, f, 'pre'); }).to.not.throw();
		expect(f.passes()).to.have.members([ 'pass1: pre' ]);
		expect(function() { FlExtensions.initialize(EXT_WITH_INIT.name, f, 'post'); }).to.not.throw();
		expect(f.passes()).to.have.members([ 'pass1: pre', 'pass1: post' ]);
	    });
	});
    });

    describe('FlClassManager', function() {
	afterEach(function() {
	    th.clear_class([ 'Cname', 'B', 'C', 'S1', 'S1S1',
			     MY_BASE_DESC.name, MY_CLASS_DESC.name, MY_CLASS1_DESC.name,
			     MY_CLASS2_DESC.name, MY_MODEL_BASE.name, MY_MODEL_CLASS.name ]);
	});

	context('register_class', function() {
	    it('should register a class with explicit name', function() {
		let C = class C {
		    constructor() { }
		};

		FlClassManager.register_class(C, 'Cname');
		expect(FlClassManager._class_registry['Cname']).to.equal(C);
	    });

	    it('should register a class with implicit name', function() {
		let C = class C {
		    constructor() { }
		};

		FlClassManager.register_class(C);
		expect(FlClassManager._class_registry['C']).to.equal(C);
	    });

	    it('should throw if not registering a class', function() {
		expect(function() { FlClassManager.register_class({}, 'foo'); }).to.throw();
	    });

	    it('should throw if ctor does not have a :name property', function() {
		let ctor = function() { };
		expect(function() { FlClassManager.register_class(function() {}); }).to.throw();
	    });

	    it('should throw if the class is already registered', function() {
		let C = class C {
		    constructor() { }
		};

		FlClassManager.register_class(C);
		expect(function() { FlClassManager.register_class(C); }).to.throw();
	    });
	});
	
	context('get_class', function() {
	    it('should find a registered class', function() {
		let C = class C {
		    constructor() { }
		};

		FlClassManager.register_class(C);

		let c = FlClassManager.get_class('C');
		expect(c).to.be.a('function');
		expect(c.name).to.equal('C');
	    });

	    it('should return a class if it looks like one', function() {
		let C = class C {
		    constructor() { }
		};

		FlClassManager.register_class(C);

		let c = FlClassManager.get_class(C);
		expect(c).to.be.a('function');
		expect(c.name).to.equal('C');
	    });

	    it('should return undefined on an unknown class', function() {
		let c = FlClassManager.get_class('NoClass');
		expect(c).to.be.undefined;
	    });

	    it('should return undefined if it does not look like a class', function() {
		let c = FlClassManager.get_class({ });
		expect(c).to.be.undefined;

	    	c = FlClassManager.get_class(function() { });
		expect(c).to.be.undefined;
	    });

	    it('can be used in a class declaration', function() {
		let Root = class Root {
		    constructor() { }
		};
		FlClassManager.register_class(Root);

		expect(function() {
		    return class Base extends FlClassManager.get_class('Root') {
			constructor() { super(); }
		    };
		}).to.not.throw();
		
		expect(function() {
		    return class Base1 extends FlClassManager.get_class(Root) {
			constructor() { super(); }
		    };
		}).to.not.throw();
	    });
	});

	context('make_class', function() {
	    it('should create a simple class', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		expect(MyBase.__name).to.equal('MyBase');
		expect(MyBase.__superclass.__name).to.equal('FlRoot');
		
		let my1 = new MyBase('A1', 'A2');

		expect(my1.__class.__name).to.equal('MyBase');
		expect(my1.__superclass.__name).to.equal('FlRoot');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		
		my1.set_msg('my1 msg');
		expect(my1.ctx().msg).to.equal('my1 msg');
	    });

	    it('should create a class with superclass', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass = FlClassManager.make_class(MY_CLASS_DESC);

		expect(MyBase.__name).to.equal('MyBase');
		expect(MyClass.__name).to.equal('MyClass');
		expect(MyClass.__superclass.__name).to.equal('MyBase');
		
		let my1 = new MyClass('A1');

		expect(my1.__class.__name).to.equal('MyClass');
		expect(my1.__superclass.__name).to.equal('MyBase');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		expect(_.isFunction(my1.my_method)).to.be.true;

		expect(my1.a1).to.equal('A1');
		expect(my1.a2).to.equal('MyClass - a2');
		
		my1.set_msg('my1 msg');
		expect(my1.ctx().msg).to.equal('my1 msg - MyClass');

		my1.my_method('my1 msg 2');
		expect(my1.ctx().msg).to.equal('my1 msg 2');
	    });

	    it('should generate an initializer correctly', function() {
		let B = FlClassManager.make_class({
		    name: 'B',
		    initializer: function(a1) {
			this.__super_init();
			this._a1 = a1;
		    }
		});

		let S1 = FlClassManager.make_class({
		    name: 'S1',
		    superclass: 'B',
		    initializer: function(a1, a2) {
			this.__super_init('B', a1);
			this._a2 = a2;
		    }
		});

		let S1S1 = FlClassManager.make_class({
		    name: 'S1S1',
		    superclass: 'S1'
		});

		let s1s1 = new S1S1('S1S1_A1', 'S1S1_A2');
		expect(s1s1._a1).to.equal('S1S1_A1');
		expect(s1s1._a2).to.equal('S1S1_A2');

		let S2 = FlClassManager.make_class({
		    name: 'S2',
		    superclass: 'B'
		});

		let S2S1 = FlClassManager.make_class({
		    name: 'S2S1',
		    superclass: 'S2',
		    initializer: function(a1, a2) {
			this.__super_init('S2', a1);
			this._a2 = a2;
		    }
		});

	    	let s2s1 = new S2S1('S2S1_A1', 'S2S1_A2');
		expect(s2s1._a1).to.equal('S2S1_A1');
		expect(s2s1._a2).to.equal('S2S1_A2');
	    });

	    it('should register class properties', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		expect(MyBase.c1).to.equal('c1');
		expect(MyBase.c2).to.equal('c2');

		MyBase.c2 = 'new c2';
		expect(MyBase.c2).to.equal('new c2');
	    });

	    it('should register instance properties', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass = FlClassManager.make_class(MY_CLASS_DESC);

		let my1 = new MyClass('A1');

		expect(my1.a1).to.equal('A1');
		expect(my1.a2).to.equal('MyClass - a2');

		my1.a2 = 'new a2';
		expect(my1.a2).to.equal('new a2');
	    });
	    
	    it('should throw on a missing :name property', function() {
		expect(function() {
		    		return FlClassManager.make_class({
				    initializer: function() {
				    },
     				    instance_methods: {
     				    }
				});
		}).to.throw();
	    });

	    it('should throw if a class is multiply defined', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		expect(function() {
		    		return FlClassManager.make_class({
				    name: 'MyBase',
				    initializer: function() {
				    },
     				    instance_methods: {
     				    }
				});
		}).to.throw();
	    });

	    it('should throw if a superclass is not defined', function() {
		expect(function() {
		    let MyClass = FlClassManager.make_class(MY_CLASS_DESC);
		}).to.throw();
	    });

	    it('should throw if an extension is not defined', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		expect(function() {
		    return FlClassManager.make_class(MY_CLASS1_DESC);
		}).to.throw();
	    });

	    it('should create a class with extensions', function() {
		let x = FlExtensions.named(EXT_WITH_INIT.name, EXT_WITH_INIT.desc);
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass1 = FlClassManager.make_class(MY_CLASS1_DESC);

		let my1 = new MyClass1('A1');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		expect(_.isFunction(my1.my_method)).to.be.true;
		expect(_.isFunction(my1.f1)).to.be.true;
		expect(_.isFunction(my1.f2)).to.be.true;
		expect(_.isFunction(my1.passes)).to.be.true;

		expect(my1.a1).to.equal('A1');
		expect(my1.a2).to.equal('MyClass1 - a2');

		expect(my1.passes()).to.have.members([ 'pass1: pre', 'pass1: post' ]);
	    });

	    it('should create a class with an extension with function methods', function() {
		let x = FlExtensions.named(EXT_FUNCTION_METHODS.name, EXT_FUNCTION_METHODS.desc);
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass2 = FlClassManager.make_class(MY_CLASS2_DESC);

		let my2 = new MyClass2('A1');

		expect(_.isFunction(my2.set_msg)).to.be.true;
		expect(_.isFunction(my2.ctx)).to.be.true;
		expect(_.isFunction(my2.my_method)).to.be.true;
		expect(_.isFunction(my2.f4)).to.be.true;
		expect(_.isFunction(my2.f4)).to.be.true;
		expect(_.isFunction(my2.c4)).to.be.false;
		expect(_.isFunction(MyClass2.c4)).to.be.true;

		expect(my2.a1).to.equal('A1');
		expect(my2.a2).to.equal('MyClass2 - a2');
	    });
	});
	
	context.skip('instance_factory', function() {
	    it('should create instance for an existing class', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);
		let MyClass = FlClassManager.make_class(MY_CLASS_DESC);

		let my1 = FlClassManager.instance_factory('MyClass', 'A100');

		expect(my1.__class.__name).to.equal('MyClass');
		expect(my1.__superclass.__name).to.equal('MyBase');

		expect(_.isFunction(my1.set_msg)).to.be.true;
		expect(_.isFunction(my1.ctx)).to.be.true;
		expect(_.isFunction(my1.my_method)).to.be.true;

		expect(my1.a1).to.equal('A100');
		expect(my1.a2).to.equal('MyClass - a2');

		my1.set_msg('my1 msg');
		expect(my1.ctx().msg).to.equal('my1 msg - MyClass');

		my1.my_method('my1 msg 2');
		expect(my1.ctx().msg).to.equal('my1 msg 2');
	    });

	    it('should fail for an unregistered class', function() {
		let MyBase = FlClassManager.make_class(MY_BASE_DESC);

		let my1 = FlClassManager.instance_factory('MyClass', 'A1');

		expect(my1).to.be.null;
	    });
	});
	
	context('modelize', function() {
	    beforeEach(function() {
		FlClassManager.make_class(MY_MODEL_BASE);
		FlClassManager.make_class(MY_MODEL_CLASS);
	    });

	    it('should return null or undefined for null or undefined input', function() {
		expect(FlClassManager.modelize('MyModelClass', null)).to.be.null;
		expect(FlClassManager.modelize('MyModelClass', undefined)).to.be.undefined;
	    });

	    it('should raise on an unregistered class', function() {
		expect(function() { return FlClassManager.modelize('NotAClass', { }); }).to.throw();
	    });
	    
	    it('should return a single object on single input', function() {
		let m1 = FlClassManager.modelize('MyModelClass', {
		    v1: 'v1',
		    doubler: 'd1'
		});

		expect(_.isObject(m1)).to.be.true;
		expect(m1.v1).to.equal('v1');
		expect(m1.doubler).to.equal('d1 - d1');
	    });
	    
	    it('should return a single object on single input (with explicit ctor)', function() {
		let MyModelClass = FlClassManager.get_class('MyModelClass');
		let m1 = FlClassManager.modelize(MyModelClass, {
		    v1: 'v1',
		    doubler: 'd1'
		});

		expect(_.isObject(m1)).to.be.true;
		expect(m1.v1).to.equal('v1');
		expect(m1.doubler).to.equal('d1 - d1');
	    });
	    
	    it('should return an an object array on array input', function() {
		let m1 = FlClassManager.modelize('MyModelClass', [
		    {
			v1: 'v1-1',
			doubler: 'd1-1'
		    },
		    {
			v1: 'v1-2',
			doubler: 'd1-2'
		    },
		]);

		expect(_.isArray(m1)).to.be.true;

		let v1 = _.map(m1, function(o, idx) { return o.v1; });
		expect(v1).to.have.members([ 'v1-1', 'v1-2' ]);

		let doubler = _.map(m1, function(o, idx) { return o.doubler; });
		expect(doubler).to.have.members([ 'd1-1 - d1-1', 'd1-2 - d1-2' ]);
	    });
	    
	    it('should return an an object array on array input (with explicit ctor)', function() {
		let MyModelClass = FlClassManager.get_class('MyModelClass');
		let m1 = FlClassManager.modelize(MyModelClass, [
		    {
			v1: 'v1-1',
			doubler: 'd1-1'
		    },
		    {
			v1: 'v1-2',
			doubler: 'd1-2'
		    },
		]);

		expect(_.isArray(m1)).to.be.true;

		let v1 = _.map(m1, function(o, idx) { return o.v1; });
		expect(v1).to.have.members([ 'v1-1', 'v1-2' ]);

		let doubler = _.map(m1, function(o, idx) { return o.doubler; });
		expect(doubler).to.have.members([ 'd1-1 - d1-1', 'd1-2 - d1-2' ]);
	    });
	});
    });

    describe('FlRoot', function() {
	afterEach(function() {
	    th.clear_class([ 'Cname', 'B', 'C', 'S1', 'S1S1',
			     MY_BASE_DESC.name, MY_CLASS_DESC.name, MY_CLASS1_DESC.name,
			     MY_CLASS2_DESC.name, MY_MODEL_BASE.name, MY_MODEL_CLASS.name ]);
	});

	context('__super', function() {
    	    it('should support nested __super calls', function() {
		let B = FlClassManager.make_class({
		    name: 'B',
		    initializer: function(a1) {
			this.__super_init();
			this._a1 = a1;
			this._ctx = [ ];			
		    },
		    instance_methods: {
			subber: function(a) {
			    this._ctx.push(`B:${a}`);
			},
			ctx: function(v) {
			    if (arguments.length > 0) this._ctx = v;
			    return this._ctx;
			}
		    }
		});

		let S1 = FlClassManager.make_class({
		    name: 'S1',
		    superclass: 'B',
		    initializer: function(a1, a2) {
			this.__super_init('B', a1);
			this._a2 = a2;
		    },
		    instance_methods: {
			subber: function(a) {
			    this.__super('B', 'subber', a);
			    this._ctx.push(`S1:${a}`);
			}
		    }
		});

		let S1S1 = FlClassManager.make_class({
		    name: 'S1S1',
		    superclass: 'S1',
		    instance_methods: {
			subber: function(a) {
			    this.__super('S1', 'subber', a);
			    this._ctx.push(`S1S1:${a}`);
			}
		    }
		});

		let s1s1 = new S1S1('S1S1_A1', 'S1S1_A2');
		s1s1.ctx([ ]);
		s1s1.subber('s');
		expect(s1s1.ctx()).to.have.members([ 'B:s', 'S1:s', 'S1S1:s' ]);
	    });
	});
    });
});
