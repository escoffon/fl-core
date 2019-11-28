require 'rails_helper'
require 'test_permission_classes'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
  c.include Fl::Core::Test::AccessHelpers
end

Fl::Core::Access::Helper.add_access_control(Fl::Core::TestDatumOne, Fl::Core::Access::GrantChecker.new())
Fl::Core::Access::Helper.add_access_control(Fl::Core::TestDatumThree, Fl::Core::Access::GrantChecker.new())

RSpec.describe 'Fl::Core::Core::ModelHash access extensions' do
  let(:_a) { Fl::Core::Access }
  let(:_ap) { _a::Permission }
  let(:_ag) { _a::Grant }

  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }
  let(:a4) { create(:test_actor, name: 'a4') }

  let(:d10) { create(:test_datum_one, owner: a1, value: 10) }
  let(:d11) { create(:test_datum_one, owner: a2, value: 11) }
  let(:d110) { create(:test_datum_one, owner: a2, value: 110) }
  let(:d12) { create(:test_datum_one, owner: a2, value: 12) }
  let(:d20) { create(:test_datum_two, owner: a1, value: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a2, value: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, value: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a3, value: 30) }
  let(:d40) { create(:test_datum_four, owner: a3, value: 'v40') }

  let(:g1) do
    p = Fl::Core::Access::Permission::Write::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d10, granted_to: a2, grants: pm)
  end
  let(:g2) do
    p = Fl::Core::Access::Permission::Read::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d10, granted_to: a3, grants: pm)
  end
  let(:g3) do
    p = Fl::Core::Access::Permission::Edit::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d11, granted_to: a1, grants: pm)
  end
  let(:g4) do
    p = Fl::Core::Access::Permission::Read::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d20, granted_to: a2, grants: pm)
  end
  let(:g5) do
    p = Fl::Core::Access::Permission::Edit::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d20, granted_to: a4, grants: pm)
  end
  let(:g6) do
    p = Fl::Core::Access::Permission::Read::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d21, granted_to: a3, grants: pm)
  end
  let(:g7) do
    p = Fl::Core::Access::Permission::Read::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d21, granted_to: a4, grants: pm)
  end
  let(:g8) do
    p = Fl::Core::Access::Permission::Write::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d12, granted_to: a1, grants: pm)
  end
  let(:g9) do
    p = Fl::Core::Access::Permission::Manage::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d30, granted_to: a4, grants: pm)
  end
  let(:g10) do
    p = Fl::Core::Access::Permission::Read::NAME
    pm = Fl::Core::Access::Permission.permission_mask(p)
    Fl::Core::Access::Grant.create(target: d40, granted_to: a4, grants: pm)
  end

  context "#to_hash" do
    it "should return correct permissions" do
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      h = d10.to_hash(a1, { verbosity: :minimal })
      expect(h[:permissions]).to include({ read: true, write: true, delete: true, index: true })

      h = d10.to_hash(a2, { verbosity: :minimal })
      expect(h[:permissions]).to include({ read: false, write: true, delete: false, index: false })

      h = d10.to_hash(a3, { verbosity: :minimal })
      expect(h[:permissions]).to include({ read: true, write: false, delete: false, index: false })

      h = d10.to_hash(a4, { verbosity: :minimal })
      expect(h[:permissions]).to include({ read: false, write: false, delete: false, index: false })

      h = d11.to_hash(a1, { verbosity: :minimal })
      expect(h[:permissions]).to include({ read: true, write: true, delete: false, index: false })

      h = d30.to_hash(a3, { verbosity: :minimal })
      expect(h[:permissions]).to include({ read: true, write: true, delete: true, index: true })

      h = d30.to_hash(a4, { verbosity: :minimal })
      expect(h[:permissions]).to include({ read: true, write: true, delete: true, index: false })
    end

    it "should customize permission list" do
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      h = d10.to_hash(a1, { verbosity: :minimal, permissions: [ :read, 'delete' ] })
      expect(h[:permissions]).to include({ read: true, delete: true })
    end
  end
end
