require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers

  c.before(:suite) do
    # Hack: ensure that a public group is defined before we start, and do it here so that if one is created
    # it will not be rolled back by individual tests
    
    pg = Fl::Core::Actor::Group.public_group
  end
end

RSpec.describe Fl::Core::Actor::GroupMember, type: :model do
  let(:id_keys) { [ :type, :global_id, :api_root, :fingerprint, :id ] }

  let(:a10) { create(:test_actor, name: 'a10') }
  let(:a11) { create(:test_actor, name: 'a11') }
  let(:a12) { create(:test_actor, name: 'a12') }
  let(:a13) { create(:test_actor, name: 'a13') }
  let(:a14) { create(:test_actor, name: 'a14') }
  let(:a15) { create(:test_actor, name: 'a15') }
  let(:a20) { create(:test_actor_two, name: 'a20') }
  let(:g10) { create(:actor_group, name: 'g10') }
  let(:g11) { create(:actor_group, name: 'g11') }

  describe '#initialize' do
    it 'should fail with empty attributes' do
      gm1 = Fl::Core::Actor::GroupMember.new
      expect(gm1.valid?).to eq(false)
      expect(gm1.errors.messages.keys).to contain_exactly(:group, :actor)
    end

    it 'should succeed with group and actor' do
      gm1 = Fl::Core::Actor::GroupMember.new(group: g10, actor: a10)
      expect(gm1.valid?).to eq(true)
      expect(gm1.group.fingerprint).to eql(g10.fingerprint)
      expect(gm1.actor.fingerprint).to eql(a10.fingerprint)
      expect(gm1.title).to be_nil
      expect(gm1.note).to be_nil
    end

    it 'should accept title and name attributes' do
      gm1 = Fl::Core::Actor::GroupMember.new(group: g10, actor: a10,
                                                  title: 'gm1', note: 'gm1 note')
      expect(gm1.valid?).to eq(true)
      expect(gm1.title).to eql('gm1')
      expect(gm1.note).to eql('gm1 note')
    end

    it 'should accept fingerprint arguments' do
      gm1 = Fl::Core::Actor::GroupMember.new(group: g10.fingerprint, actor: a10.fingerprint)
      expect(gm1.valid?).to eq(true)
      expect(gm1.group.fingerprint).to eql(g10.fingerprint)
      expect(gm1.actor.fingerprint).to eql(a10.fingerprint)
    end
  end

  describe 'creation' do
    it 'should set the fingerprint attributes' do
      gm1 = Fl::Core::Actor::GroupMember.new(group: g10.fingerprint, actor: a10.fingerprint)
      expect(gm1.valid?).to eq(true)
      expect(gm1.actor_fingerprint).to be_nil
      expect(gm1.save).to eq(true)
      expect(gm1.actor.id).to eql(a10.id)
      expect(gm1.valid?).to eq(true)
      expect(gm1.actor_fingerprint).to eql(gm1.actor.fingerprint)
      expect(gm1.actor_fingerprint).to eql(a10.fingerprint)
    end

    it 'should initialize :title if necessary' do
      gm1 = Fl::Core::Actor::GroupMember.create(group: g10.fingerprint, actor: a10.fingerprint)
      expect(gm1.valid?).to eq(true)
      expect(gm1.title).to eql("#{g10.name} - #{a10.my_name}")

      gm1 = Fl::Core::Actor::GroupMember.create(group: g10, actor: a11, title: 'explicit title')
      expect(gm1.valid?).to eq(true)
      expect(gm1.title).to eql('explicit title')
    end
    
    it 'should strip to text only for :title' do
      gm1 = Fl::Core::Actor::GroupMember.new(group: g10, actor: a10,
                                                  title: '<b>gm1</b>', note: 'gm1 note')
      expect(gm1.valid?).to eq(true)
      expect(gm1.title).to eql('gm1')
      expect(gm1.note).to eql('gm1 note')
    end

    it 'should strip dangerous HTML for :note' do
      gm1 = Fl::Core::Actor::GroupMember.new(group: g10, actor: a10,
                                                  title: '<b>gm1</b>',
                                                  note: 'gm1 <script>note</script> here')
      expect(gm1.valid?).to eq(true)
      expect(gm1.title).to eql('gm1')
      expect(gm1.note).to eql('gm1  here')
    end
  end
  
  describe 'validation' do
    it 'should fail if :actor is not an actor' do
      gm1 = Fl::Core::Actor::GroupMember.new(group: g10, actor: a20)
      expect(gm1.valid?).to eq(false)
      expect(gm1.errors.messages.keys).to contain_exactly(:actor)
    end
  end
  
  describe '#update' do
    it 'should ignore :group and :actor attributes' do
      gm1 = Fl::Core::Actor::GroupMember.create(group: g10, actor: a10,
                                                     title: 'gm1', note: 'gm1 note')
      expect(gm1.valid?).to eq(true)
      expect(gm1.group.fingerprint).to eql(g10.fingerprint)
      expect(gm1.actor.fingerprint).to eql(a10.fingerprint)
      expect(gm1.title).to eql('gm1')
      expect(gm1.note).to eql('gm1 note')

      gm1.update(group: g11, actor: a11, title: 'gm1 1', note: 'gm1 note 1')
      expect(gm1.valid?).to eq(true)
      expect(gm1.group.fingerprint).to eql(g10.fingerprint)
      expect(gm1.actor.fingerprint).to eql(a10.fingerprint)
      expect(gm1.title).to eql('gm1 1')
      expect(gm1.note).to eql('gm1 note 1')
    end
  end

  describe "group=" do
    it 'should not overwrite :group for a persisted object' do
      gm1 = Fl::Core::Actor::GroupMember.create(group: g10, actor: a10,
                                                     title: 'gm1', note: 'gm1 note')
      expect(gm1.valid?).to eq(true)
      expect(gm1.group.fingerprint).to eql(g10.fingerprint)

      gm1.group = g11
      expect(gm1.valid?).to eq(true)
      expect(gm1.group.fingerprint).to eql(g10.fingerprint)
    end
  end

  describe "actor=" do
    it 'should not overwrite :actor for a persisted object' do
      gm1 = Fl::Core::Actor::GroupMember.create(group: g10, actor: a10,
                                                     title: 'gm1', note: 'gm1 note')
      expect(gm1.valid?).to eq(true)
      expect(gm1.actor.fingerprint).to eql(a10.fingerprint)

      gm1.actor = a11
      expect(gm1.valid?).to eq(true)
      expect(gm1.actor.fingerprint).to eql(a10.fingerprint)
    end
  end
      
  describe "model hash support" do
    context "#to_hash" do
      it "should track :verbosity" do
        gm1 = Fl::Core::Actor::GroupMember.create(group: g10, actor: a10)

        h = gm1.to_hash(a10, { verbosity: :id })
        expect(h.keys).to match_array(id_keys)

        ignore_keys = id_keys | [ ]
        h = gm1.to_hash(a10, { verbosity: :ignore })
        expect(h.keys).to match_array(ignore_keys)

        minimal_keys = id_keys | [ :group, :actor, :title, :note, :created_at, :updated_at ]
        h = gm1.to_hash(a10, { verbosity: :minimal })
        expect(h.keys).to match_array(minimal_keys)

        standard_keys = minimal_keys | [ ]
        h = gm1.to_hash(a10, { verbosity: :standard })
        expect(h.keys).to match_array(standard_keys)

        verbose_keys = standard_keys | [ ]
        h = gm1.to_hash(a10, { verbosity: :verbose })
        expect(h.keys).to match_array(verbose_keys)

        complete_keys = verbose_keys | [ ]
        h = gm1.to_hash(a10, { verbosity: :complete })
        expect(h.keys).to match_array(complete_keys)
      end

      it "should customize key lists" do
        gm1 = Fl::Core::Actor::GroupMember.create(group: g10, actor: a10)

        h_keys = id_keys | [ :group ]
        h = gm1.to_hash(a10, { verbosity: :id, include: [ :group ] })
        expect(h.keys).to match_array(h_keys)

        minimal_keys = id_keys | [ :group, :actor, :title, :note, :created_at, :updated_at ]
        h_keys = minimal_keys - [ :group, :title ]
        h = gm1.to_hash(a10, { verbosity: :minimal, except: [ :group, :title ] })
        expect(h.keys).to match_array(h_keys)
      end

      it "should customize key lists for subobjects" do
        gm1 = Fl::Core::Actor::GroupMember.create(group: g10, actor: a10)

        h = gm1.to_hash(a10, { verbosity: :minimal })
        a_keys = id_keys + [ :name, :created_at, :updated_at ]
        a_keys |= [ :permissions ] if a10.respond_to?(:has_access_control?) && a10.has_access_control?
        expect(h[:actor].keys).to match_array(a_keys)

        h = gm1.to_hash(a10, {
                          verbosity: :minimal,
                          to_hash: {
                            actor: { verbosity: :minimal },
                            group: { verbosity: :id, include: :name }
                          }
                        })
        a_keys = id_keys + [ :name, :created_at, :updated_at ]
        a_keys |= [ :permissions ] if a10.respond_to?(:has_access_control?) && a10.has_access_control?
        expect(h[:actor].keys).to match_array(a_keys)
        g_keys = id_keys + [ :name ]
        expect(h[:group].keys).to match_array(g_keys)
      end
    end
  end

  describe ".build_query" do
    it 'should generate a simple query from default options' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a14 ])
      
      q = Fl::Core::Actor::GroupMember.build_query()
      ql = q.map { |gm| gm.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a10, a12, a13, a15, a11, a14 ]))
    end

    it 'should process :only_groups and :except_groups' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: g100.fingerprint)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: [ g100.fingerprint ])
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: [ g100 ])
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))

      q = Fl::Core::Actor::GroupMember.build_query(except_groups: g100.fingerprint)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a11, a12, a14 ]))
      q = Fl::Core::Actor::GroupMember.build_query(except_groups: [ g100.fingerprint ])
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a11, a12, a14 ]))
      q = Fl::Core::Actor::GroupMember.build_query(except_groups: [ g100 ])
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a11, a12, a14 ]))

      q = Fl::Core::Actor::GroupMember.build_query(except_groups: [ g100, g110.fingerprint ])
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))
    end

    it 'should process :only_actors and :except_actors' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      
      q = Fl::Core::Actor::GroupMember.build_query(only_actors: a12.fingerprint)
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ g100, g110 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(only_actors: [ a10.fingerprint, a14 ])
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ g100, g110 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(only_actors: a10)
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ g100 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(except_actors: a12.fingerprint)
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ g100, g100, g100, g110, g110 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(except_actors: [ a12.fingerprint, a10, a11 ])
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ g100, g100, g110 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(except_actors: [ a10, a11, a12, a13, a14, a15 ])
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))
    end

    it 'should filter by combination of group and actor' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: g100.fingerprint, only_actors: a10)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a10 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: [ g100 ], except_actors: a10)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ a12, a13, a15 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: [ g100 ], only_actors: [ a11, a14 ])
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))
    end

    it 'should process :order, :offset, :limit' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: g100, except_actors: [ a12 ],
                                                        offset: 1, limit: 1, order: 'id')
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a13 ]))
      
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: g100,
                                                        offset: 1, limit: 2, order: 'id DESC')
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a13, a12 ]))
    end

    it 'should support sorting by title' do
      g100 = create(:actor_group, actors: [ a10, [ a12, 'aaaa a12' ], a13, a15 ])
      
      q = Fl::Core::Actor::GroupMember.build_query(only_groups: g100, order: 'id')
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a10, a12, a13, a15 ]))

      q = Fl::Core::Actor::GroupMember.build_query(only_groups: g100, order: 'title')
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a12, a10, a13, a15 ]))
    end
  end

  describe ".query_for_group" do
    it 'should restrict to the given group' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      
      q = Fl::Core::Actor::GroupMember.query_for_group(g100, order: 'id ASC')
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a10, a12, a13, a15 ]))

      q = Fl::Core::Actor::GroupMember.query_for_group(g110, only_actors: [ a11 ], order: 'id ASC')
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a11 ]))
      
      q = Fl::Core::Actor::GroupMember.query_for_group(g110, except_actors: [ a11 ], order: 'id ASC')
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a12, a14 ]))

      q = Fl::Core::Actor::GroupMember.query_for_group(g100, order: 'id DESC', offset: 1, limit: 1)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a13 ]))
    end
  end

  describe ".query_for_actor" do
    it 'should restrict to the given actor' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      g120 = create(:actor_group, actors: [ a14 ])
      g130 = create(:actor_group, actors: [ a12, a13 ])

      q = Fl::Core::Actor::GroupMember.query_for_actor(a10, order: 'id ASC')
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ g100 ]))

      q = Fl::Core::Actor::GroupMember.query_for_actor(a12, order: 'id ASC')
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ g100, g110, g130 ]))

      q = Fl::Core::Actor::GroupMember.query_for_actor(a14, order: 'id DESC')
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ g120, g110 ]))

      q = Fl::Core::Actor::GroupMember.query_for_actor(a12, order: 'id ASC', offset: 1, limit: 1)
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ g110 ]))
    end
  end

  describe ".query_for_actor_in_group" do
    it 'should find an actor in group' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      q = Fl::Core::Actor::GroupMember.query_for_actor_in_group(a13, g100)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a13 ]))
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ g100 ]))

      q = Fl::Core::Actor::GroupMember.query_for_actor_in_group(a12, g110.fingerprint)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a12 ]))
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ g110 ]))

      q = Fl::Core::Actor::GroupMember.query_for_actor_in_group(a15.fingerprint, g100)
      ql = q.map { |li| li.actor }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ a15 ]))
      ql = q.map { |li| li.group }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ g100 ]))
    end

    it 'should not find a listable not in list' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      q = Fl::Core::Actor::GroupMember.query_for_actor_in_group(a14, g100)
      expect(q.first).to be_nil

      q = Fl::Core::Actor::GroupMember.query_for_actor_in_group(a14, "#{g100.class.name}/0")
      expect(q.first).to be_nil

      q = Fl::Core::Actor::GroupMember.query_for_actor_in_group("TestActor/0", g100)
      expect(q.first).to be_nil

      q = Fl::Core::Actor::GroupMember.query_for_actor_in_group("TestActor/0", "#{g100.class.name}/0")
      expect(q.first).to be_nil
    end
  end

  describe ".find_actor_in_group" do
    it 'should find an actor in group' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      a = Fl::Core::Actor::GroupMember.find_actor_in_group(a13, g100)
      expect(a).not_to be_nil
      expect(a.fingerprint).to eql(a13.fingerprint)

      a = Fl::Core::Actor::GroupMember.find_actor_in_group(a12, g110.fingerprint)
      expect(a).not_to be_nil
      expect(a.fingerprint).to eql(a12.fingerprint)

      a = Fl::Core::Actor::GroupMember.find_actor_in_group(a15.fingerprint, g100)
      expect(a).not_to be_nil
      expect(a.fingerprint).to eql(a15.fingerprint)
    end

    it 'should not find an actor not in group' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      a = Fl::Core::Actor::GroupMember.find_actor_in_group(a14, g100)
      expect(a).to be_nil

      a = Fl::Core::Actor::GroupMember.find_actor_in_group(a14, "#{g100.class.name}/0")
      expect(a).to be_nil

      a = Fl::Core::Actor::GroupMember.find_actor_in_group("TestActor/0", g100)
      expect(a).to be_nil

      a = Fl::Core::Actor::GroupMember.find_actor_in_group("TestActor/0", "#{g100.class.name}/0")
      expect(a).to be_nil
    end
  end

  describe ".resolve_actor" do
    it 'should return a group member as is' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])

      gm = g100.members.first
      o = Fl::Core::Actor::GroupMember.resolve_actor(gm, g100)
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a10.fingerprint)
    end

    it 'should process a fingerprint' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])

      o = Fl::Core::Actor::GroupMember.resolve_actor(a14.fingerprint, g100)
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a14.fingerprint)
    end

    it 'should process a model instance' do
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      o = Fl::Core::Actor::GroupMember.resolve_actor(a10, g110)
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g110.fingerprint)
      expect(o.actor.fingerprint).to eql(a10.fingerprint)
    end

    it 'should process a hash' do
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      o = Fl::Core::Actor::GroupMember.resolve_actor({ actor: a13 }, g110)
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g110.fingerprint)
      expect(o.actor.fingerprint).to eql(a13.fingerprint)

      o = Fl::Core::Actor::GroupMember.resolve_actor({ actor: a13.fingerprint }, g110)
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g110.fingerprint)
      expect(o.actor.fingerprint).to eql(a13.fingerprint)

      o = Fl::Core::Actor::GroupMember.resolve_actor({ actor: a13, group: g10 }, g110)
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g110.fingerprint)
      expect(o.actor.fingerprint).to eql(a13.fingerprint)
    end

    it 'should fail if a group member is not in group' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      gm = g100.members.first
      o = Fl::Core::Actor::GroupMember.resolve_actor(gm, g110)
      expect(o).to be_an_instance_of(String)
    end

    it 'should fail if the actor is not an actor' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])

      o = Fl::Core::Actor::GroupMember.resolve_actor(a20, g100)
      expect(o).to be_an_instance_of(String)

      o = Fl::Core::Actor::GroupMember.resolve_actor(a20.fingerprint, g100)
      expect(o).to be_an_instance_of(String)

      o = Fl::Core::Actor::GroupMember.resolve_actor({ actor: a20 }, g100)
      expect(o).to be_an_instance_of(String)
    end
  end

  describe ".normalize_actors" do
    it 'should resolve correctly' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      actors = [ g100.members.first,
                 a11.fingerprint, a11,
                 { actor: a11 }, { actor: a11.fingerprint },
                 g110.members.first,
                 a20, a20.fingerprint, { actor: a20 },
                 { actor: a15, title: 'a15 title' }
               ]
      errcount, resolved = Fl::Core::Actor::GroupMember.normalize_actors(actors, g100)
      expect(errcount).to eql(4)
      
      o = resolved[0]
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a10.fingerprint)

      o = resolved[1]
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a11.fingerprint)

      o = resolved[2]
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a11.fingerprint)

      o = resolved[3]
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a11.fingerprint)

      o = resolved[4]
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a11.fingerprint)

      o = resolved[5]
      expect(o).to be_an_instance_of(String)

      o = resolved[6]
      expect(o).to be_an_instance_of(String)

      o = resolved[7]
      expect(o).to be_an_instance_of(String)

      o = resolved[8]
      expect(o).to be_an_instance_of(String)

      o = resolved[9]
      expect(o).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(o.group.fingerprint).to eql(g100.fingerprint)
      expect(o.actor.fingerprint).to eql(a15.fingerprint)
      expect(o.title).to eql('a15 title')
    end
  end
end
