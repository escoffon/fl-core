require 'rails_helper'
require 'test_permission_classes'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
  c.include Fl::Core::Test::AccessHelpers
end

RSpec.describe Fl::Core::Access::Actor do
  let(:_a) { Fl::Core::Access }
  let(:_ap) { _a::Permission }
  let(:_ag) { _a::Grant }

  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }
  let(:a4) { create(:test_actor, name: 'a4') }

  let(:d10) do
    d10 = create(:test_datum_one, owner: a1, value: 10)

    p = _ap::Edit::NAME
    pm = _ap.permission_mask(p)
    Fl::Core::Access::Grant.add_grant(pm, a2, d10)

    p = _ap::Read::NAME
    pm = _ap.permission_mask(p)
    Fl::Core::Access::Grant.add_grant(pm, a3, d10)

    d10
  end

  let(:d11) do
    d11 = create(:test_datum_one, owner: a2, value: 11)

    p = _ap::Manage::NAME
    pm = _ap.permission_mask(p)
    Fl::Core::Access::Grant.add_grant(pm, a4, d11)

    d11
  end
  
  context 'when included' do
    it 'should register instance methods' do
      expect(TestActor.instance_methods).to include(:find_grant_for, :delete_actor_grants)
      expect(a1.methods).to include(:find_grant_for, :delete_actor_grants)
    end
  end

  context '#find_grant_for' do
    it 'should find the correct grant' do
      g = a1.find_grant_for(d10)
      expect(g).to be_a(_ag)
      expect(g.granted_to.fingerprint).to eql(a1.fingerprint)
      expect(g.target.fingerprint).to eql(d10.fingerprint)
      p = _ap::Owner::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      g = a2.find_grant_for(d10)
      expect(g).to be_a(_ag)
      expect(g.granted_to.fingerprint).to eql(a2.fingerprint)
      expect(g.target.fingerprint).to eql(d10.fingerprint)
      p = _ap::Edit::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      g = a4.find_grant_for(d11)
      expect(g).to be_a(_ag)
      expect(g.granted_to.fingerprint).to eql(a4.fingerprint)
      expect(g.target.fingerprint).to eql(d11.fingerprint)
      p = _ap::Manage::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      g = a3.find_grant_for(d11)
      expect(g).to be_nil
    end
  end

  context 'before_destroy callback' do
    it 'should remove all grants for the actor' do
      # this creates the grants
      dl = [ d10, d11 ]

      gq = _ag.where('(granted_to_fingerprint = :afp)', afp: a2.fingerprint)
      expect(gq.count).to eql(2)
      expect do
        a2.destroy
      end.to change(_ag, :count).by(-2)
      gq = _ag.where('(granted_to_fingerprint = :afp)', afp: a2.fingerprint)
      expect(gq.count).to eql(0)
    end
  end
end
