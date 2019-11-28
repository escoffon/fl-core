require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe Fl::Core::Actor::Actor, type: :model do
  let(:a10) { create(:test_actor, name: 'a10') }
  let(:a11) { create(:test_actor, name: 'a11') }
  let(:a12) { create(:test_actor, name: 'a12') }
  let(:a13) { create(:test_actor, name: 'a13') }
  let(:a14) { create(:test_actor, name: 'a14') }
  let(:a15) { create(:test_actor, name: 'a15') }
  let(:a20) { create(:test_actor_two, name: 'a20') }
  let(:a21) { create(:test_actor_two, name: 'a21') }
  let(:d10_title) { 'd10 - title' }
  let(:d20_title) { 'd20 - title' }
  let(:d30_title) { 'd30 - title' }
  let(:d10_content) { 'd10 - content' }
  let(:d20_content) { 'd20 - content' }
  let(:d30_content) { 'd30 - content' }
  let(:d10) { create(:test_datum_one, owner: a10, title: d10_title, content: d10_content) }
  let(:d20) { create(:test_datum_two, owner: a11, title: d20_title, content: d20_content) }
  let(:d30) { create(:test_datum_three, owner: a11, title: d30_title, content: d30_content) }

  describe '#is_actor?' do
    it 'should be defined for all ActiveRecord classes' do
      expect(a10.methods).to include(:is_actor?)
      expect(a11.methods).to include(:is_actor?)
      expect(a20.methods).to include(:is_actor?)
      expect(a21.methods).to include(:is_actor?)
      expect(d10.methods).to include(:is_actor?)
      expect(d20.methods).to include(:is_actor?)
      expect(d30.methods).to include(:is_actor?)

      expect(Fl::Core::TestActor.methods).to include(:is_actor?)
      expect(Fl::Core::TestActorTwo.methods).to include(:is_actor?)
      expect(Fl::Core::TestDatumOne.methods).to include(:is_actor?)
      expect(Fl::Core::TestDatumTwo.methods).to include(:is_actor?)
      expect(Fl::Core::TestDatumThree.methods).to include(:is_actor?)
    end

    it 'should return true for classes marked actor' do
      expect(a10.is_actor?).to eql(true)
      expect(a11.is_actor?).to eql(true)
      expect(a20.is_actor?).to eql(false)
      expect(a21.is_actor?).to eql(false)
      expect(d10.is_actor?).to eql(false)
      expect(d20.is_actor?).to eql(false)
      expect(d30.is_actor?).to eql(false)

      expect(Fl::Core::TestActor.is_actor?).to eql(true)
      expect(Fl::Core::TestActorTwo.is_actor?).to eql(false)
      expect(Fl::Core::TestDatumOne.is_actor?).to eql(false)
      expect(Fl::Core::TestDatumTwo.is_actor?).to eql(false)
      expect(Fl::Core::TestDatumThree.is_actor?).to eql(false)
    end
  end
  
  describe '#actor_containers' do
    it 'should return the correct groups' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      
      a13_c = a13.actor_containers
      a13_g = a13_c.map { |gm| gm.group }
      expect(obj_fingerprints(a13_g)).to match_array(obj_fingerprints([ g100 ]))
      a13_a = a13_c.map { |gm| gm.actor }
      expect(obj_fingerprints(a13_a)).to match_array(obj_fingerprints([ a13 ]))
      expect(obj_fingerprints(a13.groups)).to match_array(obj_fingerprints([ g100 ]))

      a12_c = a12.actor_containers
      a12_g = a12_c.map { |gm| gm.group }
      expect(obj_fingerprints(a12_g)).to match_array(obj_fingerprints([ g100, g110 ]))
      a12_a = a12_c.map { |gm| gm.actor }
      expect(obj_fingerprints(a12_a)).to match_array(obj_fingerprints([ a12, a12 ]))
      expect(obj_fingerprints(a12.groups)).to match_array(obj_fingerprints([ g100, g110 ]))
    end

    it 'should remove a destroyed object from all groups' do
      g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
      g110 = create(:actor_group, actors: [ a11, a12, a14 ])
      
      expect(obj_fingerprints(g100.actors)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))
      expect(obj_fingerprints(g110.actors)).to eql(obj_fingerprints([ a11, a12, a14 ]))

      a10.destroy
      g100.reload
      g110.reload
      expect(obj_fingerprints(g100.actors)).to match_array(obj_fingerprints([ a12, a13, a15 ]))
      expect(obj_fingerprints(g110.actors)).to eql(obj_fingerprints([ a11, a12, a14 ]))

      a12.destroy
      g100.reload
      g110.reload
      expect(obj_fingerprints(g100.actors)).to match_array(obj_fingerprints([ a13, a15 ]))
      expect(obj_fingerprints(g110.actors)).to eql(obj_fingerprints([ a11, a14 ]))
    end
  end

  describe 'group management' do
    context '#groups' do
      it 'should return the correct list' do
        g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        expect(obj_fingerprints(g100.actors)).to match_array(obj_fingerprints([ a10, a12, a13, a15 ]))
        expect(obj_fingerprints(g110.actors)).to eql(obj_fingerprints([ a11, a12, a14 ]))
      end
    end
    
    context '#add_to_group' do
      it 'should add the actor if not already in the group' do
        g100 = create(:actor_group, actors: [ a10, a12 ])
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        expect(obj_fingerprints(a13.groups)).to match_array(obj_fingerprints([ ]))
        
        gm = a13.add_to_group(g100)
        expect(gm).to be_an_instance_of(Fl::Core::Actor::GroupMember)
        expect(gm.group.fingerprint).to eql(g100.fingerprint)
        expect(gm.actor.fingerprint).to eql(a13.fingerprint)
        expect(obj_fingerprints(a13.actor_containers)).to match_array(obj_fingerprints([ gm ]))
        expect(obj_fingerprints(a13.groups)).to match_array(obj_fingerprints([ g100 ]))

        gm1 = a13.add_to_group(g100)
        expect(obj_fingerprints(a13.actor_containers)).to match_array(obj_fingerprints([ gm ]))
      end
    end
    
    context '#remove_from_group' do
      it 'should remove the actor if in the group' do
        g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        expect(a12.remove_from_group(g100)).to eql(true)
        expect(obj_fingerprints(a12.groups)).to eql(obj_fingerprints([ g110 ]))
      end
      
      it 'should do nothing if the actor is not the group' do
        g100 = create(:actor_group, actors: [ a10, a12, a13, a15 ])
        g110 = create(:actor_group, actors: [ a11, a12, a14 ])

        expect(a10.remove_from_group(g110)).to eql(false)
        expect(a12.remove_from_group(g110)).to eql(true)
        expect(a12.remove_from_group(g110)).to eql(false)
      end
    end
  end
end
