require 'rails_helper'
require 'test_permission_classes'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
  c.include Fl::Core::Test::AccessHelpers
end

RSpec.describe Fl::Core::TestCheckerOne do
  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }
  let(:a4) { create(:test_actor, name: 'a4') }

  let(:d10) { create(:test_datum_one, owner: a1, title: 'd10') }
  let(:d11) { create(:test_datum_one, owner: a1, title: 'd11') }
  let(:d12) { create(:test_datum_one, owner: a1, title: 'd12') }
  let(:d13) { create(:test_datum_one, owner: a1, title: 'd3') }

  let(:c1) do
    Fl::Core::TestCheckerOne.new([
                                   [ d10, [ [ a1, [ Fl::Core::Access::Permission::Edit::NAME ] ],
                                            [ a2, [ Fl::Core::Access::Permission::Read::NAME,
                                                    Fl::Core::Access::Permission::Delete::NAME ] ] ] ],
                                   [ d12, [ [ a1, [ Fl::Core::Access::Permission::Read::NAME ] ],
                                            [ a2, [ Fl::Core::Access::Permission::Read::NAME,
                                                    Fl::Core::Access::Permission::Write::NAME ] ] ] ]
                                 ])
  end

  describe "#access_check" do
    it "should grant permission if present for actor/asset" do
      g = c1.access_check(Fl::Core::Access::Permission::Delete::NAME, a2, d10)
      expect(g).to eql(true)
    end

    it "should not grant permission if not all bits are present" do
      g = c1.access_check(Fl::Core::Access::Permission::Edit::NAME, a1, d12)
      expect(g).to eql(false)
    end

    it "should not grant permission if not present for actor/asset" do
      g = c1.access_check(Fl::Core::Access::Permission::Write::NAME, a1, d12)
      expect(g).to eql(false)
    end

    it "should not grant permission if asset is not present" do
      g = c1.access_check(Fl::Core::Access::Permission::Write::NAME, a1, d11)
      expect(g).to eql(false)
    end

    it "should not grant permission if actor is not present" do
      g = c1.access_check(Fl::Core::Access::Permission::Write::NAME, a3, d10)
      expect(g).to eql(false)
    end

    it "should grant permission using forward grants" do
      g = c1.access_check(Fl::Core::Access::Permission::Write::NAME, a1, d10)
      expect(g).to eql(true)
    end

    it "should accept permission classes" do
      g = c1.access_check(Fl::Core::Access::Permission::Delete, a2, d10)
      expect(g).to eql(true)
    end

    it "should not grant permission for unknown permission" do
      g = c1.access_check(:unknown, a1, d12)
      expect(g).to eql(false)
    end
  end
end
