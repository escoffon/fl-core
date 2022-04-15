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

RSpec.describe Fl::Core::Actor::Group, type: :model do
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

  describe 'public group' do
    it 'should exist' do
      expect(Fl::Core::Actor::Group.public_group).to be_a(Fl::Core::Actor::Group)
    end

    it 'should not be deleted' do
      pg = Fl::Core::Actor::Group.public_group
      
      expect(pg).to be_a(Fl::Core::Actor::Group)
      pg_id = pg.id
      npg = nil
      expect do
        npg = Fl::Core::Actor::Group.find(pg_id)
      end.not_to raise_error
      expect(npg.id).to eql(pg_id)
      
      pg.destroy
      expect do
        npg = Fl::Core::Actor::Group.find(pg_id)
      end.not_to raise_error
      expect(npg.id).to eql(pg_id)
    end
  end
  
  describe 'validation' do
    it 'should fail with empty attributes' do
      g1 = Fl::Core::Actor::Group.new
      expect(g1.valid?).to eq(false)
      expect(g1.errors.messages).to include(:name)
    end

    it 'should succeed with a nonempty :name attribute' do
      g1 = Fl::Core::Actor::Group.new(name: 'g1')
      expect(g1.valid?).to eq(true)
    end

    it 'should fail with duplicate name' do
      g1 = Fl::Core::Actor::Group.create(name: 'g1')
      expect(g1.valid?).to eq(true)

      g1_1 = Fl::Core::Actor::Group.create(name: 'g1')
      expect(g1_1.valid?).to eq(false)
      expect(g1_1.errors.messages).to include(:name)

      g2 = Fl::Core::Actor::Group.new(name: 'g2')
      expect(g2.valid?).to eq(true)

      g2_1 = Fl::Core::Actor::Group.new(name: 'g2')
      expect(g2_1.valid?).to eq(true)

      expect(g2.save).to eql(true)
      expect(g2_1.save).to eql(false)
      expect(g2_1.errors.messages).to include(:name)
    end

    it 'should validate duplicate name in case insensitive' do
      g1 = Fl::Core::Actor::Group.create(name: 'g1')
      expect(g1.valid?).to eq(true)

      g1_1 = Fl::Core::Actor::Group.create(name: 'G1')
      expect(g1_1.valid?).to eq(false)
      expect(g1_1.errors.messages).to include(:name)
    end
  end

  describe '#initialize' do
    it 'should generate default values' do
      g1 = Fl::Core::Actor::Group.new(name: 'g1')
      expect(g1.note).to be_a_kind_of(String)
      expect(g1.note.length).to be > 0

      note = 'the note'
      g2 = Fl::Core::Actor::Group.new(name: 'g2', note: note)
      expect(g2.note).to be_a_kind_of(String)
      expect(g2.note).to eql(note)
    end
    
    context "the :actors pseudoattribute" do
      it 'should support various input fomats' do
        g1 = Fl::Core::Actor::Group.new(name: 'g1', actors: [
                                               a10,
                                               a12.fingerprint,
                                               { actor: a14 },
                                               { actor: a11, title: 'a11:title' }
                                           ])

        # the member count is 0 because g1 has not yet been saved
        expect(g1.valid?).to eql(true)
        expect(g1.members.count).to eql(0)

        # We need to save the list so that the list items are also saved
        expect(g1.save).to eql(true)
        expect(g1.members.count).to eql(4)

        al = g1.members.map { |gm| gm.actor }
        expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a10, a12, a14, a11 ]))

        al = g1.members.map { |gm| "#{gm.actor.fingerprint}-#{gm.title}" }
        expect(al).to match_array([
                                    "#{a10.fingerprint}-#{g1.name} - #{a10.my_name}",
                                    "#{a12.fingerprint}-#{g1.name} - #{a12.my_name}",
                                    "#{a14.fingerprint}-#{g1.name} - #{a14.my_name}",
                                    "#{a11.fingerprint}-a11:title"
                                  ])
      end

      it 'should raise an exception with a non-actor object' do
        exc = nil
      
        expect do
          begin
            g1 = Fl::Core::Actor::Group.new(name: 'g1', actors: [ a11, a20 ])
          rescue Exception => x
            exc = x
            raise x
          end
        end.to raise_exception(Fl::Core::Actor::Group::NormalizationError)

        expect(exc.errors.length).to eql(1)
      end
    end
  end

  context 'creation' do
    it 'should set the fingerprint attributes' do
      g1 = Fl::Core::Actor::Group.new(name: 'g1', actors: [ a10, a12 ], owner: a10)

      expect(g1.valid?).to eq(true)
      expect(g1.owner_fingerprint).to be_nil
      
      expect(g1.save).to eq(true)
      expect(g1.owner_fingerprint).to eql(g1.owner.fingerprint)
      expect(g1.owner_fingerprint).to eql(a10.fingerprint)
    end
  end

  describe '#update' do
    it 'should update the list of actors' do
      note = 'g1 note'
      g1 = Fl::Core::Actor::Group.create(name: 'g1', actors: [ a10, a12 ], note: note)

      expect(g1.valid?).to be (true)
      expect(g1.note).to eql(note)
      expect(obj_fingerprints(g1.actors)).to match_array(obj_fingerprints([ a10, a12 ]))

      new_note = 'new note'
      expect(g1.update(note: new_note, actors: [
                         a10,
                         a14.fingerprint,
                         { actor: a11 },
                         { actor: a13.fingerprint },
                         { actor: a15.fingerprint, title: 'a15' }
                       ])).to eql(true)
      expect(g1.note).to eql(new_note)
      expect(obj_fingerprints(g1.actors)).to match_array(obj_fingerprints([ a10, a14, a11, a13, a15 ]))
    end
    
    it 'should raise an exception with a non-listable object' do
      exc = nil
      note = 'g1 note'
      g1 = Fl::Core::Actor::Group.create(name: 'g1', actors: [ a10, a12 ], note: note)

      expect(g1.valid?).to be (true)
      expect(g1.note).to eql(note)
      expect(obj_fingerprints(g1.actors)).to match_array(obj_fingerprints([ a10, a12 ]))

      new_note = 'new note'
      expect do
        begin
          g1.update(note: new_note, actors: [ a11, a20 ])
        rescue Exception => x
          exc = x
          raise x
        end
      end.to raise_exception(Fl::Core::Actor::Group::NormalizationError)

      expect(exc.errors.length).to eql(1)
    end
  end

  describe '.build_query' do
    let(:g1) { create(:actor_group, actors: [ a10, a12 ], owner: a10) }
    let(:g2) { create(:actor_group, actors: [ a10, a14, a15 ], owner: a10) }
    let(:g3) { create(:actor_group, actors: [ a13 ], owner: a12) }
    let(:g4) { create(:actor_group, actors: [ a12, a14 ], owner: a13) }
    let(:g5) { create(:actor_group, actors: [ a15 ], owner: a12) }
    let(:g6) { create(:actor_group, actors: [ a15, a12, a10 ], owner: a10) }

    it 'should return all lists with default options' do
      # trigger the list creation
      gl = [ g1, g2, g3, g4, g5, g6 ]
      
      q = Fl::Core::Actor::Group.build_query()
      xl = gl  | [ Fl::Core::Actor::Group.public_group ]
      expect(obj_fingerprints(q)).to match_array(obj_fingerprints(xl))
    end

    it 'should support :only_owners and :except_owners' do
      # trigger the list creation
      xl = [ g1, g2, g3, g4, g5, g6 ]
      
      q = Fl::Core::Actor::Group.build_query(only_owners: a10)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1, g2, g6 ]))
      q = Fl::Core::Actor::Group.build_query(only_owners: a10.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1, g2, g6 ]))
      
      q = Fl::Core::Actor::Group.build_query(only_owners: [ a13, a10.fingerprint ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1, g2, g4, g6 ]))
      
      q = Fl::Core::Actor::Group.build_query(except_owners: a12)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1, g2, g4, g6 ]))
      q = Fl::Core::Actor::Group.build_query(except_owners: a12.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1, g2, g4, g6 ]))
      
      q = Fl::Core::Actor::Group.build_query(except_owners: [ a13, a10.fingerprint ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g3, g5 ]))
      
      q = Fl::Core::Actor::Group.build_query(except_owners: a12, only_owners: a12.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ ]))
      
      q = Fl::Core::Actor::Group.build_query(except_owners: a12, only_owners: [ a12.fingerprint, a13 ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ g4 ]))
    end

    it 'should support order and pagination options' do
      # trigger the list creation
      gl = [ g1, g2, g3, g4, g5, g6 ]
      
      q = Fl::Core::Actor::Group.build_query(order: 'id')
      xl = gl  | [ Fl::Core::Actor::Group.public_group ]
      expect(obj_fingerprints(q)).to eql(obj_fingerprints(xl).sort)

      q = Fl::Core::Actor::Group.build_query(only_owners: a10, order: 'id')
      expect(obj_fingerprints(q)).to eql(obj_fingerprints([ g1, g2, g6 ]))

      q = Fl::Core::Actor::Group.build_query(only_owners: a10, order: 'id', limit: 2, offset: 1)
      expect(obj_fingerprints(q)).to eql(obj_fingerprints([ g2, g6 ]))
    end      
  end
  
  describe '#find_group_member' do
    it 'should find an object in the list' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])

      gm = g100.find_group_member(a10)
      expect(gm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(gm.group.fingerprint).to eql(g100.fingerprint)
      expect(gm.actor.fingerprint).to eql(a10.fingerprint)

      gm = g100.find_group_member(a10.fingerprint)
      expect(gm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
      expect(gm.group.fingerprint).to eql(g100.fingerprint)
      expect(gm.actor.fingerprint).to eql(a10.fingerprint)
    end

    it 'should not find an object not in the list' do
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      gm = g110.find_group_member(a10)
      expect(gm).to be_nil
    end
  end

  describe "actor management" do
    context '#actors' do
      it 'should return the correct value' do
        g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        al = g10.actors
        expect(al.count).to eql(0)

        al = g100.actors
        expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))

        al = g110.actors
        expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a11, a12, a14 ]))
      end
    end

    context "#add_actor" do
      it "should add an actor" do
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        gm = g110.add_actor(a13)
        expect(gm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
        expect(obj_fingerprints(g110.actors)).to match_array(obj_fingerprints([ a11, a12, a14, a13 ]))
      end

      it "should add an object with a member title and note" do
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])
        title = 'a13 title'
        note = 'a13 note'
        
        gm = g110.add_actor(a15, title, note)
        expect(gm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
        expect(gm.title).to eql(title)
        expect(gm.note).to eql(note)
        expect(obj_fingerprints(g110.actors)).to match_array(obj_fingerprints([ a11, a12, a14, a15 ]))
      end

      it "should not add an actor already in the group" do
        g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])

        ogm = g100.find_group_member(a12)
        expect(ogm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
        
        gm = g100.add_actor(a12)
        expect(gm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
        expect(gm.fingerprint).to eql(ogm.fingerprint)
        expect(obj_fingerprints(g100.actors)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))
      end

      it "should add a non-actor, but validation should fail" do
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        gm = g110.add_actor(a20)
        expect(gm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
        expect(g110.save).to eql(false)
        expect(g110.errors.messages.keys).to include(:"members.actor", :members)
        expect(obj_fingerprints(g110.actors)).to match_array(obj_fingerprints([ a11, a12, a14, a20 ]))
      end
    end

    context "#remove_actor" do
      it "should remove an object" do
        g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        g100.remove_actor(a13)
        expect(obj_fingerprints(g100.actors)).to match_array(obj_fingerprints([ a10, a12, a15 ]))

        g110.remove_actor(a12)
        expect(obj_fingerprints(g110.actors)).to match_array(obj_fingerprints([ a11, a14 ]))
      end

      it "should not remove an actor that is not in the group" do
        g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])

        g100.remove_actor(a11)
        expect(obj_fingerprints(g100.actors)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))
      end
    end
  end

  describe "#query_group_members" do
    it "should return the full list with default options" do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      al = g100.query_group_members().map { |gm| gm.actor }
      expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))

      al = g110.query_group_members().map { |gm| gm.actor }
      expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a11, a12, a14 ]))
    end

    it "should ignore :only_groups and :except_groups" do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      al = g100.query_group_members(except_groups: g100).map { |gm| gm.actor }
      expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))

      al = g110.query_group_members(only_groups: g100).map { |gm| gm.actor }
      expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a11, a12, a14 ]))
    end

    it "should accept additional options" do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])

      al = g100.query_group_members(order: 'id ASC', limit: 2, offset: 1).map { |gm| gm.actor }
      expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a12, a13 ]))

      al = g110.query_group_members(order: 'id DESC').map { |gm| gm.actor }
      expect(obj_fingerprints(al)).to match_array(obj_fingerprints([ a14, a12, a11 ]))
    end
  end

  describe "group as actor" do
    it "can be added to a group" do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14, g100 ])

      expect(obj_fingerprints(g100.actors.to_a)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))
      expect(obj_fingerprints(g110.actors.to_a)).to match_array(obj_fingerprints([ a11, a12, a14, g100 ]))
    end

    it "tracks group membership" do
      g100 = create(:actor_group, actors: [ a10 ])
      g110 = create(:actor_group, actors: [ a12, g100 ])

      expect(obj_fingerprints(g100.groups)).to match_array(obj_fingerprints([ g110 ]))
      expect(obj_fingerprints(g110.groups)).to match_array(obj_fingerprints([ ]))
    end
  end

  describe "model hash support" do
    context "#to_hash" do
      it "should track :verbosity" do
        g100 = create(:actor_group, owner: a12, actors: [ a10, a12, a13, a15 ])

        h = g100.to_hash(a10, { verbosity: :id })
        expect(h.keys).to match_array(id_keys)

        ignore_keys = id_keys | [ ]
        h = g100.to_hash(a10, { verbosity: :ignore })
        expect(h.keys).to match_array(ignore_keys)

        minimal_keys = id_keys | [ :name, :note, :owner, :created_at, :updated_at ]
        h = g100.to_hash(a10, { verbosity: :minimal })
        expect(h.keys).to match_array(minimal_keys)

        standard_keys = minimal_keys | [ ]
        h = g100.to_hash(a10, { verbosity: :standard })
        expect(h.keys).to match_array(standard_keys)

        verbose_keys = standard_keys | [ :members, :groups ]
        h = g100.to_hash(a10, { verbosity: :verbose })
        expect(h.keys).to match_array(verbose_keys)

        complete_keys = verbose_keys | [ ]
        h = g100.to_hash(a10, { verbosity: :complete })
        expect(h.keys).to match_array(complete_keys)
      end

      it "should customize key lists" do
        g100 = create(:actor_group, owner: a12, actors: [ a10, a12, a13, a15 ])

        h_keys = id_keys | [ :name ]
        h = g100.to_hash(a10, { verbosity: :id, include: [ :name ] })
        expect(h.keys).to match_array(h_keys)

        minimal_keys = id_keys | [ :name, :note, :owner, :created_at, :updated_at ]
        h_keys = minimal_keys - [ :owner, :name ]
        h = g100.to_hash(a10, { verbosity: :minimal, except: [ :owner, :name ] })
        expect(h.keys).to match_array(h_keys)
      end

      it "should customize key lists for subobjects" do
        g100 = create(:actor_group, owner: a12, actors: [ a10, a12, a13, a15 ])
        g110 = create(:actor_group, actors: [ a11, a12, a14, g100 ])

        h = g100.to_hash(a10, { verbosity: :minimal, include: [ :members, :groups ] })
        o_keys = id_keys + [ :name, :created_at, :updated_at ]
        m_keys = id_keys + [ :actor, :group, :title, :note, :created_at, :updated_at ]
        g_keys = id_keys + [ :name, :note, :owner, :created_at, :updated_at ]
        expect(h[:owner].keys).to match_array(o_keys)
        expect(h[:members][0].keys).to match_array(m_keys)
        expect(h[:groups][0].keys).to match_array(g_keys)

        h = g100.to_hash(a10, {
                           verbosity: :minimal,
                           include: [ :members, :groups ],
                           to_hash: {
                             owner: { verbosity: :id },
                             members: { verbosity: :id, include: [ :title, :note ] },
                             groups: { verbosity: :id, include: [ :name ] }
                           }
                         })
        o_keys = id_keys + [ ]
        m_keys = id_keys + [ :title, :note ]
        g_keys = id_keys + [ :name ]
        expect(h[:owner].keys).to match_array(o_keys)
        expect(h[:members][0].keys).to match_array(m_keys)
        expect(h[:groups][0].keys).to match_array(g_keys)
      end
    end
  end
end
