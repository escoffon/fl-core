const _ = require('lodash');
const { FlExtensions, FlClassManager } = require('fl/core/object_system');
const {
    FlModelBase, FlModelCache, FlModelFactory, FlGlobalModelFactory
} = require('fl/core/model_factory');
const {
    ActiveStorageAttachment, ActiveStorageAttachedOne, ActiveStorageAttachedMany
} = require('fl/core/active_storage');
const th = require('test_helpers');

const MY_CONTAINER_DESC = {
    name: 'ContainerTestModel',
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

const CONTAINER_1 = {
    type: "Container::Test::Model",
    api_root: "/container/test/models",
    url_path: "container_test_model_path/1",
    fingerprint: "Container::Test::Model/1",
    id: 1,
    created_at: "2019-01-17 19:23:14 UTC",
    updated_at: "2019-01-17 23:46:28 UTC",
    images: {
	type: "ActiveStorage::Attached::Many",
	name: "images",
	attachments: [
	    {
		type: "ActiveStorage::Attachment",
		name: "images",
		content_type: "image/jpeg",
		original_filename: "spring.jpg",
		original_byte_size: 142363,
		variants: [
		    {
			style: "xlarge",
			params: {resize: "1200x1200>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDQT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--8dd3c182cca5e8cd905838b83c931ca39bec2c2b/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lQTVRJd01IZ3hNakF3UGdZNkJrVlUiLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--5aefd7d63ade7a1786f9e5649907081b9d1a0136/spring.jpg"
		    },
		    {
			style: "large",
			params: {resize: "600x600>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDQT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--8dd3c182cca5e8cd905838b83c931ca39bec2c2b/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTmpBd2VEWXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--b363f72353e0243fac93b387380cc8884858d9e6/spring.jpg"
		    },
		    {
			style: "medium",
			params: {resize: "400x400>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDQT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--8dd3c182cca5e8cd905838b83c931ca39bec2c2b/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTkRBd2VEUXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--47507fb3e5538b7396000b2cce78c7a71a0c7474/spring.jpg"
		    },
		    {
			style: "small",
			params: {resize: "200x200>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDQT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--8dd3c182cca5e8cd905838b83c931ca39bec2c2b/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTWpBd2VESXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--9fe64214c9d86f5975dddd8f8c5888cc15fb571e/spring.jpg"
		    },
		    {
			style: "thumb",
			params: {resize: "100x100>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDQT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--8dd3c182cca5e8cd905838b83c931ca39bec2c2b/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTVRBd2VERXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--9d90a3b2a38b18d85df0a708c7ab708275189354/spring.jpg"
		    },
		    {
			style: "iphone",
			params: {resize: "64x64>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDQT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--8dd3c182cca5e8cd905838b83c931ca39bec2c2b/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lMTmpSNE5qUStCam9HUlZRPSIsImV4cCI6bnVsbCwicHVyIjoidmFyaWF0aW9uIn19--c4197a559271aefce3a073520bb28a8b40e58d6d/spring.jpg"
		    },
		    {
			style: "original",
			params: {},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDQT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--8dd3c182cca5e8cd905838b83c931ca39bec2c2b/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdBQT09IiwiZXhwIjpudWxsLCJwdXIiOiJ2YXJpYXRpb24ifX0=--8ce1f252ccb18928ba41c392f30cb46e3dc1a876/spring.jpg"
		    }
		],
		created_at: "2019-01-17 23:27:04 UTC"
	    },
	    {
		type: "ActiveStorage::Attachment",
		name: "images",
		content_type: "image/jpeg",
		original_filename: "rosone.jpg",
		original_byte_size: 74581,
		variants: [
		    {
			style: "xlarge",
			params: {resize: "1200x1200>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDUT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--2f22b326cc1c4b5d3b9b8d83b933bc69182fb52a/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lQTVRJd01IZ3hNakF3UGdZNkJrVlUiLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--5aefd7d63ade7a1786f9e5649907081b9d1a0136/rosone.jpg"
		    },
		    {
			style: "large",
			params: {resize: "600x600>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDUT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--2f22b326cc1c4b5d3b9b8d83b933bc69182fb52a/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTmpBd2VEWXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--b363f72353e0243fac93b387380cc8884858d9e6/rosone.jpg"
		    },
		    {
			style: "medium",
			params: {resize: "400x400>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDUT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--2f22b326cc1c4b5d3b9b8d83b933bc69182fb52a/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTkRBd2VEUXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--47507fb3e5538b7396000b2cce78c7a71a0c7474/rosone.jpg"
		    },
		    {
			style: "small",
			params: {resize: "200x200>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDUT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--2f22b326cc1c4b5d3b9b8d83b933bc69182fb52a/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTWpBd2VESXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--9fe64214c9d86f5975dddd8f8c5888cc15fb571e/rosone.jpg"
		    },
		    {
			style: "thumb",
			params: {resize: "100x100>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDUT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--2f22b326cc1c4b5d3b9b8d83b933bc69182fb52a/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lOTVRBd2VERXdNRDRHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--9d90a3b2a38b18d85df0a708c7ab708275189354/rosone.jpg"
		    },
		    {
			style: "iphone",
			params: {resize: "64x64>"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDUT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--2f22b326cc1c4b5d3b9b8d83b933bc69182fb52a/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCam9MY21WemFYcGxTU0lMTmpSNE5qUStCam9HUlZRPSIsImV4cCI6bnVsbCwicHVyIjoidmFyaWF0aW9uIn19--c4197a559271aefce3a073520bb28a8b40e58d6d/rosone.jpg"
		    },
		    {
			style: "original",
			params: {},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDUT09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--2f22b326cc1c4b5d3b9b8d83b933bc69182fb52a/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdBQT09IiwiZXhwIjpudWxsLCJwdXIiOiJ2YXJpYXRpb24ifX0=--8ce1f252ccb18928ba41c392f30cb46e3dc1a876/rosone.jpg"
		    }
		],
		created_at: "2019-01-17 23:46:28 UTC"
	    }
	]
    },
    policies: {
	type: "ActiveStorage::Attached::Many",
	name: "policies",
	attachments: [
	    {
		type: "ActiveStorage::Attachment",
		name: "policies",
		content_type: "application/pdf",
		original_filename: "policy_one.pdf",
		original_byte_size: 14335,
		variants: [
		    {
			style: "original",
			params: {},
			url: "/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCdz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--0e17e2838c483810ee75489a03bd8aa882799f46/policy_one.pdf"
		    }
		],
		created_at: "2019-01-17 22:51:22 UTC"
	    }
	]
    },
    avatar: {
	type: "ActiveStorage::Attached::One",
	name: "avatar",
	attachments: [
	    {
		type: "ActiveStorage::Attachment",
		name: "avatar",
		content_type: "image/png",
		original_filename: "default_avatar.png",
		original_byte_size: 17615,
		variants: [
		    {
			style: "xlarge",
			params: {resize: "200x200>",strip: true,background: "rgba(255,255,255,0)"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--47e90ff8163afa818bdb7df58b7781ce56f47ea1/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdDRG9MY21WemFYcGxTU0lOTWpBd2VESXdNRDRHT2daRlZEb0tjM1J5YVhCVU9nOWlZV05yWjNKdmRXNWtTU0lZY21kaVlTZ3lOVFVzTWpVMUxESTFOU3d3S1FZN0JsUT0iLCJleHAiOm51bGwsInB1ciI6InZhcmlhdGlvbiJ9fQ==--9d2c75b897d1d139084e3078a7b383b8fbe6fa38/default_avatar.png"
		    },
		    {
			style: "large",
			params: {resize: "72x72>",strip: true,background: "rgba(255,255,255,0)"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--47e90ff8163afa818bdb7df58b7781ce56f47ea1/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdDRG9MY21WemFYcGxTU0lMTnpKNE56SStCam9HUlZRNkNuTjBjbWx3VkRvUFltRmphMmR5YjNWdVpFa2lHSEpuWW1Fb01qVTFMREkxTlN3eU5UVXNNQ2tHT3daVSIsImV4cCI6bnVsbCwicHVyIjoidmFyaWF0aW9uIn19--6efa46ab1064fedd42c82706872634460c9493e7/default_avatar.png"
		    },
		    {
			style: "medium",
			params: {resize: "48x48>",strip: true,background: "rgba(255,255,255,0)"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--47e90ff8163afa818bdb7df58b7781ce56f47ea1/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdDRG9MY21WemFYcGxTU0lMTkRoNE5EZytCam9HUlZRNkNuTjBjbWx3VkRvUFltRmphMmR5YjNWdVpFa2lHSEpuWW1Fb01qVTFMREkxTlN3eU5UVXNNQ2tHT3daVSIsImV4cCI6bnVsbCwicHVyIjoidmFyaWF0aW9uIn19--ae79cade6e005b0c20f0d493660450f9dc914ee9/default_avatar.png"
		    },
		    {
			style: "thumb",
			params: {resize: "32x32>",strip: true,background: "rgba(255,255,255,0)"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--47e90ff8163afa818bdb7df58b7781ce56f47ea1/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdDRG9MY21WemFYcGxTU0lMTXpKNE16SStCam9HUlZRNkNuTjBjbWx3VkRvUFltRmphMmR5YjNWdVpFa2lHSEpuWW1Fb01qVTFMREkxTlN3eU5UVXNNQ2tHT3daVSIsImV4cCI6bnVsbCwicHVyIjoidmFyaWF0aW9uIn19--0efe365c790b18d1aa7f8227b7118e0dd7f40b17/default_avatar.png"
		    },
		    {
			style: "list",
			params: {resize: "24x24>",strip: true,background: "rgba(255,255,255,0)"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--47e90ff8163afa818bdb7df58b7781ce56f47ea1/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdDRG9MY21WemFYcGxTU0lMTWpSNE1qUStCam9HUlZRNkNuTjBjbWx3VkRvUFltRmphMmR5YjNWdVpFa2lHSEpuWW1Fb01qVTFMREkxTlN3eU5UVXNNQ2tHT3daVSIsImV4cCI6bnVsbCwicHVyIjoidmFyaWF0aW9uIn19--547a28ae28297565c0d34d1dc102f849e10e7bcc/default_avatar.png"
		    },
		    {
			style: "original",
			params: {strip: true,background: "rgba(255,255,255,0)"},
			url: "/rails/active_storage/representations/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCZz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--47e90ff8163afa818bdb7df58b7781ce56f47ea1/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaDdCem9LYzNSeWFYQlVPZzlpWVdOclozSnZkVzVrU1NJWWNtZGlZU2d5TlRVc01qVTFMREkxTlN3d0tRWTZCa1ZVIiwiZXhwIjpudWxsLCJwdXIiOiJ2YXJpYXRpb24ifX0=--59fa59577c1304c5c7e3bf274b6c8cb6e23b132a/default_avatar.png"
		    }
		],
		created_at: "2019-01-17 19:42:55 UTC"
	    }
	]
    }
};

describe('fl.active_storage module', function() {
    before(function() {
	FlClassManager.make_class(MY_CONTAINER_DESC);
    });
    
    after(function() {
	th.clear_class(MY_CONTAINER_DESC.name);
    });

    context('loading', function() {
	it('should register the ActiveStorageAttachment class', function() {
	    expect(_.isNil(FlClassManager.get_class('ActiveStorageAttachment'))).to.be.false;
	});

	it('should register the ActiveStorageAttachedOne class', function() {
	    expect(_.isNil(FlClassManager.get_class('ActiveStorageAttachedOne'))).to.be.false;
	});

	it('should register the ActiveStorageAttachedMany class', function() {
	    expect(_.isNil(FlClassManager.get_class('ActiveStorageAttachedMany'))).to.be.false;
	});
    });
    
    describe('ActiveStorageAttachment', function() {
	context('creation', function() {
	    it('with new should create an instance of the model class', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);

		expect(mm).to.be.an.instanceof(ActiveStorageAttachment);
	    });

	    it('with new should load data into properties', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);

		let data_keys = _.reduce(CONTAINER_1.avatar.attachments[0], function(acc, mv, mk) {
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
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);

		expect(mm.created_at).to.be.an.instanceof(Date);
	    });

	    it('with modelize should create an instance of the model class', function() {
		let mm = FlClassManager.modelize('ActiveStorageAttachment',
						 CONTAINER_1.avatar.attachments[0]);
		expect(mm).to.be.an.instanceof(ActiveStorageAttachment);
	    });

	    it('with modelize should load data into properties', function() {
		let mm = FlClassManager.modelize('ActiveStorageAttachment',
						 CONTAINER_1.avatar.attachments[0]);

		let data_keys = _.reduce(CONTAINER_1.avatar.attachments[0], function(acc, mv, mk) {
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
		let mm = FlClassManager.modelize('ActiveStorageAttachment',
						 CONTAINER_1.avatar.attachments[0]);

		expect(mm.created_at).to.be.an.instanceof(Date);
	    });
	});
	
	context('#refresh', function() {
	    it('should set properties from data', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);

		_.forEach(CONTAINER_1.avatar.attachments[0], function(mv, mk) {
		    if (mk == 'created_at')
		    {
			let d = new Date(mv);
			expect(mm[mk].toString()).to.equal(d.toString());
		    }
		    else if (mk == 'variants')
		    {
			let cv = CONTAINER_1.avatar.attachments[0].variants;
			
			_.forEach(mm.variants, function(v, vidx) {
			    let xv = cv[vidx];

			    expect(v.style).to.eql(xv.style);
			    expect(v.url).to.eql(xv.url);
			    expect(v.params).to.eql(xv.params);
			});
		    }
		    else
		    {
			expect(mm[mk]).to.equal(mv);
		    }
		});
	    });
	    
	    it('should refresh partial data', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);

		expect(mm.name).to.equal(CONTAINER_1.avatar.attachments[0].name);
		expect(mm.content_type).to.equal(CONTAINER_1.avatar.attachments[0].content_type);
		mm.refresh({ name: 'new.name' });
		expect(mm.name).to.equal('new.name');
		expect(mm.content_type).to.equal(CONTAINER_1.avatar.attachments[0].content_type);
	    });
	});
	
	context('#variant', function() {
	    it('should find a known variant', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);
		let xv = CONTAINER_1.avatar.attachments[0].variants[1];
		let v = mm.variant('large');
		
		expect(v).to.not.be.undefined;
		expect(v.style).to.eql(xv.style);
		expect(v.url).to.eql(xv.url);
		expect(v.params).to.eql(xv.params);
	    });

	    it('should return undefined for an unknown variant', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);
		let v = mm.variant('nothere');
		
		expect(v).to.be.undefined;
	    });
	});
	
	context('#variant_url', function() {
	    it('should return the URL from a known variant', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);
		let xurl = CONTAINER_1.avatar.attachments[0].variants[2].url;
		let url = mm.variant_url('medium');
		
		expect(url).to.eql(xurl);
	    });

	    it('should return null for an unknown variant', function() {
		let mm = new ActiveStorageAttachment(CONTAINER_1.avatar.attachments[0]);
		let url = mm.variant_url('nothere');
		
		expect(url).to.be.null;
	    });
	});
    });

    describe('ActiveStorageAttachedOne', function() {
	context('creation', function() {
	    it('with new should create an instance of the model class', function() {
		let mm = new ActiveStorageAttachedOne(CONTAINER_1.avatar);

		expect(mm).to.be.an.instanceof(ActiveStorageAttachedOne);
	    });

	    it('with new should load data into properties', function() {
		let mm = new ActiveStorageAttachedOne(CONTAINER_1.avatar);

		let data_keys = _.reduce(CONTAINER_1.avatar, function(acc, mv, mk) {
		    acc.push(mk);
		    return acc;
		}, [ ]);
		let obj_keys = _.reduce(data_keys, function(acc, ov, oidx) {
		    if (!_.isUndefined(mm[ov])) acc.push(ov);
		    return acc;
		}, [ ]);
		expect(obj_keys).to.have.members(data_keys);
	    });

	    it('with modelize should create an instance of the model class', function() {
		let mm = FlClassManager.modelize('ActiveStorageAttachedOne', CONTAINER_1.avatar);
		expect(mm).to.be.an.instanceof(ActiveStorageAttachedOne);
	    });

	    it('with modelize should load data into properties', function() {
		let mm = FlClassManager.modelize('ActiveStorageAttachedOne', CONTAINER_1.avatar);

		let data_keys = _.reduce(CONTAINER_1.avatar, function(acc, mv, mk) {
		    acc.push(mk);
		    return acc;
		}, [ ]);
		let obj_keys = _.reduce(data_keys, function(acc, ov, oidx) {
		    if (!_.isUndefined(mm[ov])) acc.push(ov);
		    return acc;
		}, [ ]);
		expect(obj_keys).to.have.members(data_keys);
	    });
	});
	
	context('#refresh', function() {
	    it('should set properties from data', function() {
		let mm = new ActiveStorageAttachedOne(CONTAINER_1.avatar);

		expect(mm.type).to.eql(CONTAINER_1.avatar.type);
		expect(mm.name).to.eql(CONTAINER_1.avatar.name);
		expect(mm.attachments).to.be.an.instanceof(Array);
	    });

	    it('should convert attachment hashes to objects', function() {
		let mm = new ActiveStorageAttachedOne(CONTAINER_1.avatar);

		expect(mm.attachments.length).to.eql(CONTAINER_1.avatar.attachments.length);
		expect(mm.attachments[0]).to.be.an.instanceof(ActiveStorageAttachment);
	    });
	});
	
	context('#attachment', function() {
	    it('should return the attachment', function() {
		let mm = new ActiveStorageAttachedOne(CONTAINER_1.avatar);

		let a = mm.attachment;
		let aa = mm.attachments[0];
		
		expect(a).to.be.an.instanceof(ActiveStorageAttachment);
		expect(a).to.eql(aa);
	    });
	});
    });

    describe('ActiveStorageAttachedMany', function() {
	context('creation', function() {
	    it('with new should create an instance of the model class', function() {
		let mm = new ActiveStorageAttachedMany(CONTAINER_1.images);

		expect(mm).to.be.an.instanceof(ActiveStorageAttachedMany);
	    });

	    it('with new should load data into properties', function() {
		let mm = new ActiveStorageAttachedMany(CONTAINER_1.images);

		let data_keys = _.reduce(CONTAINER_1.images, function(acc, mv, mk) {
		    acc.push(mk);
		    return acc;
		}, [ ]);
		let obj_keys = _.reduce(data_keys, function(acc, ov, oidx) {
		    if (!_.isUndefined(mm[ov])) acc.push(ov);
		    return acc;
		}, [ ]);
		expect(obj_keys).to.have.members(data_keys);
	    });

	    it('with modelize should create an instance of the model class', function() {
		let mm = FlClassManager.modelize('ActiveStorageAttachedMany', CONTAINER_1.images);
		expect(mm).to.be.an.instanceof(ActiveStorageAttachedMany);
	    });

	    it('with modelize should load data into properties', function() {
		let mm = FlClassManager.modelize('ActiveStorageAttachedMany', CONTAINER_1.images);

		let data_keys = _.reduce(CONTAINER_1.images, function(acc, mv, mk) {
		    acc.push(mk);
		    return acc;
		}, [ ]);
		let obj_keys = _.reduce(data_keys, function(acc, ov, oidx) {
		    if (!_.isUndefined(mm[ov])) acc.push(ov);
		    return acc;
		}, [ ]);
		expect(obj_keys).to.have.members(data_keys);
	    });
	});
	
	context('#refresh', function() {
	    it('should set properties from data', function() {
		let mm = new ActiveStorageAttachedMany(CONTAINER_1.images);

		expect(mm.type).to.eql(CONTAINER_1.images.type);
		expect(mm.name).to.eql(CONTAINER_1.images.name);
		expect(mm.attachments).to.be.an.instanceof(Array);
	    });

	    it('should convert attachment hashes to objects', function() {
		let mm = new ActiveStorageAttachedMany(CONTAINER_1.images);

		expect(mm.attachments.length).to.eql(CONTAINER_1.images.attachments.length);
		expect(mm.attachments[0]).to.be.an.instanceof(ActiveStorageAttachment);
	    });
	});
    });
});
