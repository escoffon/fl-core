require 'rails_helper'
require 'test_permission_classes'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
  c.include Fl::Core::Test::AccessHelpers
end

RSpec.describe Fl::Core::Access::Permission, type: :model do
  def xpnames(pl)
    pl.map { |p| p.name }
  end
  
  before(:example) do
    cleanup_permission_registry([ TestAccess::P1::NAME, TestAccess::P2::NAME, TestAccess::P3::NAME,
                                  TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ])

    @initial_count = Fl::Core::Access::Permission.instance_variable_get(:@_permission_registry).count
  end
  
  describe "registry" do
    context "built-in permissions" do
      it "should have been registered correctly" do
        xr = [ Fl::Core::Access::Permission::Owner::NAME,
               Fl::Core::Access::Permission::Read::NAME,
               Fl::Core::Access::Permission::Write::NAME,
               Fl::Core::Access::Permission::Delete::NAME,
               Fl::Core::Access::Permission::Edit::NAME,
               Fl::Core::Access::Permission::Manage::NAME,
               Fl::Core::Access::Permission::Create::NAME,
               Fl::Core::Access::Permission::Index::NAME,
               Fl::Core::Actor::Permission::ManageMembers::NAME ]
        
        expect(Fl::Core::Access::Permission.registered).to match_array(xr)
      end

      it "should have registered grants correctly" do
        pg = Fl::Core::Access::Permission.permission_grantors
        expect(pg.keys).to match_array([ Fl::Core::Access::Permission::Owner::NAME,
                                         Fl::Core::Access::Permission::Read::NAME,
                                         Fl::Core::Access::Permission::Write::NAME,
                                         Fl::Core::Access::Permission::Delete::NAME,
                                         Fl::Core::Access::Permission::Edit::NAME,
                                         Fl::Core::Access::Permission::Manage::NAME,
                                         Fl::Core::Access::Permission::Create::NAME,
                                         Fl::Core::Access::Permission::Index::NAME,
                                         Fl::Core::Actor::Permission::ManageMembers::NAME ])
        expect(pg[:read]).to match_array([ :edit, :manage ])
        expect(pg[:write]).to match_array([ :edit, :manage ])
        expect(pg[:delete]).to match_array([ :manage ])
        expect(pg[:edit]).to match_array([ :manage ])
        expect(pg[:manage]).to match_array([ ])
        expect(pg[:create]).to match_array([ ])
        expect(pg[:manage_actor_group_members]).to match_array([ ])
        expect(pg[:owner]).to match_array([ ])
      end

      it "should have appropriate class name accessors" do
        expect(Fl::Core::Access::Permission::Read.name).to eql(Fl::Core::Access::Permission::Read::NAME)
        expect(Fl::Core::Access::Permission::Write.name).to eql(Fl::Core::Access::Permission::Write::NAME)
        expect(Fl::Core::Access::Permission::Delete.name).to eql(Fl::Core::Access::Permission::Delete::NAME)
        expect(Fl::Core::Access::Permission::Edit.name).to eql(Fl::Core::Access::Permission::Edit::NAME)
        expect(Fl::Core::Access::Permission::Manage.name).to eql(Fl::Core::Access::Permission::Manage::NAME)
      end
    end
    
    context ".registered" do
      it "should return all registered permissions" do
        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register

        xr = [ Fl::Core::Access::Permission::Owner::NAME,
               Fl::Core::Access::Permission::Read::NAME,
               Fl::Core::Access::Permission::Write::NAME,
               Fl::Core::Access::Permission::Delete::NAME,
               Fl::Core::Access::Permission::Edit::NAME,
               Fl::Core::Access::Permission::Manage::NAME,
               Fl::Core::Access::Permission::Create::NAME,
               Fl::Core::Access::Permission::Index::NAME,
               Fl::Core::Actor::Permission::ManageMembers::NAME,
               TestAccess::P1::NAME,
               TestAccess::P2::NAME ]
        
        expect(Fl::Core::Access::Permission.registered).to match_array(xr)
      end
    end
    
    context ".lookup" do
      it "should find a registered permission" do
        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register
        mp3 = TestAccess::P3.new.register
        mp4 = TestAccess::P4.new.register

        p1_1 = Fl::Core::Access::Permission.lookup(TestAccess::P1::NAME)
        expect(p1_1).to be_a_kind_of(Fl::Core::Access::Permission)
        expect(p1_1).to be_an_instance_of(TestAccess::P1)
        expect(p1_1.name).to eql(TestAccess::P1::NAME)
        expect(p1_1.grantors).to contain_exactly(TestAccess::P4::NAME)

        p4_1 = Fl::Core::Access::Permission.lookup(TestAccess::P4::NAME)
        expect(p4_1).to be_a_kind_of(Fl::Core::Access::Permission)
        expect(p4_1).to be_an_instance_of(TestAccess::P4)
        expect(p4_1.name).to eql(TestAccess::P4::NAME)
        expect(p4_1.grantors).to contain_exactly()
      end

      it "should return nil for an unregistered permission" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new

        expect(Fl::Core::Access::Permission.lookup(TestAccess::P4::NAME)).to be_nil
        expect(Fl::Core::Access::Permission.lookup(:unregistered)).to be_nil
      end        

      it "should accept string arguments" do
        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register
        mp3 = TestAccess::P3.new.register
        mp4 = TestAccess::P4.new.register

        p1 = Fl::Core::Access::Permission.lookup(TestAccess::P1::NAME.to_s)
        expect(p1).to be_an_instance_of(TestAccess::P1)
      end
    end
    
    context ".grantors_for_permission" do
      it "should find grantors correctly" do
        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register
        mp3 = TestAccess::P3.new.register
        mp4 = TestAccess::P4.new.register
        mp5 = TestAccess::P5.new.register
        mp6 = TestAccess::P6.new.register

        pc = Fl::Core::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp1.name)).to match_array(m1)

        m2 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp2.name)).to match_array(m2)

        m3 = [ TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp3.name)).to match_array(m3)

        m4 = [ TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp4.name)).to match_array(m4)

        m5 = [ TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp5.name)).to match_array(m5)

        m6 = [ ]
        expect(pc.grantors_for_permission(mp6.name)).to match_array(m6)
      end

      it "should accept string arguments" do
        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register
        mp3 = TestAccess::P3.new.register
        mp4 = TestAccess::P4.new.register
        mp5 = TestAccess::P5.new.register
        mp6 = TestAccess::P6.new.register

        pc = Fl::Core::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp1.name.to_s)).to match_array(m1)
      end

      it "should accept instance arguments" do
        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register
        mp3 = TestAccess::P3.new.register
        mp4 = TestAccess::P4.new.register
        mp5 = TestAccess::P5.new.register
        mp6 = TestAccess::P6.new.register

        pc = Fl::Core::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp1)).to match_array(m1)
      end

      it "should accept class arguments" do
        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register
        mp3 = TestAccess::P3.new.register
        mp4 = TestAccess::P4.new.register
        mp5 = TestAccess::P5.new.register
        mp6 = TestAccess::P6.new.register

        pc = Fl::Core::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(TestAccess::P1)).to match_array(m1)
      end
    end

    context ".permission_mask" do
      it "should expand correctly" do
        pc = Fl::Core::Access::Permission
        
        expect(pc.permission_mask(pc::Owner::NAME)).to eql(pc::Owner::BIT)
        expect(pc.permission_mask(pc::Create::NAME)).to eql(pc::Create::BIT)
        expect(pc.permission_mask(pc::Read::NAME)).to eql(pc::Read::BIT)
        expect(pc.permission_mask(pc::Write::NAME)).to eql(pc::Write::BIT)
        expect(pc.permission_mask(pc::Delete::NAME)).to eql(pc::Delete::BIT)
        expect(pc.permission_mask(pc::Edit::NAME)).to eql(pc::Read::BIT | pc::Write::BIT)
        expect(pc.permission_mask(pc::Manage::NAME)).to eql(pc::Read::BIT | pc::Write::BIT | pc::Delete::BIT)

        mp1 = TestAccess::P1.new.register
        mp2 = TestAccess::P2.new.register
        mp3 = TestAccess::P3.new.register
        mp4 = TestAccess::P4.new.register
        mp5 = TestAccess::P5.new.register
        mp6 = TestAccess::P6.new.register
        
        expect(pc::permission_mask(mp1.name)).to eql(mp1.bit)
        expect(pc::permission_mask(mp2.name)).to eql(mp2.bit)
        expect(pc::permission_mask(mp3.name)).to eql(mp3.bit)
        expect(pc::permission_mask(mp4.name)).to eql(mp1.bit | mp2.bit)
        expect(pc::permission_mask(mp5.name)).to eql(mp1.bit | mp2.bit | mp3.bit)
        expect(pc::permission_mask(mp6.name)).to eql(mp1.bit | mp2.bit | mp3.bit)
      end
    end
  end

  describe "#initialize" do
    it "should not register an instance automatically" do
      r = Fl::Core::Access::Permission.instance_variable_get(:@_permission_registry)
      expect(r.count).to eql(@initial_count)
        
      mp1 = TestAccess::P1.new
      expect(r.count).to eql(@initial_count)

      p1 = Fl::Core::Access::Permission.lookup(TestAccess::P1::NAME)
      expect(p1).to be_nil
    end
  end
  
  describe "#register" do
    it "should raise on a duplicate permission" do
      r = Fl::Core::Access::Permission.instance_variable_get(:@_permission_registry)
      expect(r.count).to eql(@initial_count)
        
      mp1 = TestAccess::P1.new.register
      expect(r.count).to eql(@initial_count + 1)

      expect do
        mp1_1 = TestAccess::P1.new.register
      end.to raise_exception(Fl::Core::Access::Permission::Duplicate)
    end
  end

  describe "#permission_mask" do
    it "should expand correctly" do
      pc = Fl::Core::Access::Permission
      
      p = pc.lookup(pc::Owner::NAME)
      expect(p.permission_mask).to eql(pc::Owner::BIT)

      p = pc.lookup(pc::Create::NAME)
      expect(p.permission_mask).to eql(pc::Create::BIT)

      p = pc.lookup(pc::Read::NAME)
      expect(p.permission_mask).to eql(pc::Read::BIT)

      p = pc.lookup(pc::Write::NAME)
      expect(p.permission_mask).to eql(pc::Write::BIT)

      p = pc.lookup(pc::Delete::NAME)
      expect(p.permission_mask).to eql(pc::Delete::BIT)

      p = pc.lookup(pc::Edit::NAME)
      expect(p.permission_mask).to eql(pc::Read::BIT | pc::Write::BIT)

      p = pc.lookup(pc::Manage::NAME)
      expect(p.permission_mask).to eql(pc::Read::BIT | pc::Write::BIT | pc::Delete::BIT)

      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register
      
      expect(mp1.permission_mask).to eql(mp1.bit)
      expect(mp2.permission_mask).to eql(mp2.bit)
      expect(mp3.permission_mask).to eql(mp3.bit)
      expect(mp4.permission_mask).to eql(mp1.bit | mp2.bit)
      expect(mp5.permission_mask).to eql(mp1.bit | mp2.bit | mp3.bit)
      expect(mp6.permission_mask).to eql(mp1.bit | mp2.bit | mp3.bit)
    end
  end

  describe "#expand_grants" do
    it "should expand correctly" do
      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register

      expect(xpnames(mp1.expand_grants)).to match_array([ ])
      expect(xpnames(mp2.expand_grants)).to match_array([ ])
      expect(xpnames(mp3.expand_grants)).to match_array([ ])
      expect(xpnames(mp4.expand_grants)).to match_array([ TestAccess::P1::NAME, TestAccess::P2::NAME])
      expect(xpnames(mp5.expand_grants)).to match_array([ TestAccess::P3::NAME,
                                                          TestAccess::P1::NAME, TestAccess::P2::NAME])
      expect(xpnames(mp6.expand_grants)).to match_array([ TestAccess::P3::NAME,
                                                          TestAccess::P1::NAME, TestAccess::P2::NAME])
    end
  end
  
  describe "#grantors" do
    it "should expand correctly (sequential tests)" do
      mp1 = TestAccess::P1.new.register
      expect(mp1.grantors).to match_array([ ])
      mp2 = TestAccess::P2.new.register
      expect(mp1.grantors).to match_array([ ])
      expect(mp2.grantors).to match_array([ ])
      mp3 = TestAccess::P3.new.register
      expect(mp1.grantors).to match_array([ ])
      expect(mp2.grantors).to match_array([ ])
      expect(mp3.grantors).to match_array([ ])
      mp4 = TestAccess::P4.new.register
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME ])
      expect(mp3.grantors).to match_array([ ])
      expect(mp4.grantors).to match_array([ ])
      mp5 = TestAccess::P5.new.register
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME ])
      expect(mp3.grantors).to match_array([ TestAccess::P5::NAME ])
      expect(mp4.grantors).to match_array([ TestAccess::P5::NAME ])
      expect(mp5.grantors).to match_array([ ])
      mp6 = TestAccess::P6.new.register
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp3.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp4.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp5.grantors).to match_array([ TestAccess::P6::NAME ])
      expect(mp6.grantors).to match_array([ ])
    end

    it "should expand correctly (generic tests)" do
      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp3.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp4.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp5.grantors).to match_array([ TestAccess::P6::NAME ])
      expect(mp6.grantors).to match_array([ ])
    end
  end
end
