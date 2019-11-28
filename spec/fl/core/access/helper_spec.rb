require 'rails_helper'
require 'test_permission_classes'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
  c.include Fl::Core::Test::AccessHelpers
end

class MyBase < Fl::Core::Access::Permission
  NAME = :my_base
end

class MyPermission < MyBase
  NAME = :my_permission
  BIT = 0x00100000
  
  def initialize()
    super(NAME, BIT, [ ])
  end
end

MyPermission.new

class B
end

class S < B
end

RSpec.describe Fl::Core::Access::Permission, type: :model do
  after(:example) do
    cleanup_permission_registry([ MyPermission::NAME,
                                  TestAccess::P1::NAME, TestAccess::P2::NAME, TestAccess::P3::NAME,
                                  TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ])
  end

  let(:_h) { Fl::Core::Access::Helper }

  describe ".permission_name" do
    it "should return symbol and string arguments" do
      n = Fl::Core::Access::Permission::Read::NAME
      expect(Fl::Core::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Core::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Core::Access::Permission::Write::NAME
      expect(Fl::Core::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Core::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Core::Access::Permission::Delete::NAME
      expect(Fl::Core::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Core::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Core::Access::Permission::Edit::NAME
      expect(Fl::Core::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Core::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Core::Access::Permission::Manage::NAME
      expect(Fl::Core::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Core::Access::Helper.permission_name(n.to_s)).to eql(n)
    end

    it "should process Permission arguments" do
      n = Fl::Core::Access::Permission::Read::NAME
      p = Fl::Core::Access::Permission.lookup(n)
      expect(Fl::Core::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Core::Access::Permission::Write::NAME
      p = Fl::Core::Access::Permission.lookup(n)
      expect(Fl::Core::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Core::Access::Permission::Delete::NAME
      p = Fl::Core::Access::Permission.lookup(n)
      expect(Fl::Core::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Core::Access::Permission::Edit::NAME
      p = Fl::Core::Access::Permission.lookup(n)
      expect(Fl::Core::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Core::Access::Permission::Manage::NAME
      p = Fl::Core::Access::Permission.lookup(n)
      expect(Fl::Core::Access::Helper.permission_name(p)).to eql(n)
    end

    it "should process Class arguments" do
      n = Fl::Core::Access::Permission::Read::NAME
      c = Fl::Core::Access::Permission::Read
      expect(Fl::Core::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Core::Access::Permission::Write::NAME
      c = Fl::Core::Access::Permission::Write
      expect(Fl::Core::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Core::Access::Permission::Delete::NAME
      c = Fl::Core::Access::Permission::Delete
      expect(Fl::Core::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Core::Access::Permission::Edit::NAME
      c = Fl::Core::Access::Permission::Edit
      expect(Fl::Core::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Core::Access::Permission::Manage::NAME
      c = Fl::Core::Access::Permission::Manage
      expect(Fl::Core::Access::Helper.permission_name(c)).to eql(n)

      n = MyPermission::NAME
      c = MyPermission
      expect(Fl::Core::Access::Helper.permission_name(c)).to eql(n)

      expect(Fl::Core::Access::Helper.permission_name(S)).to be_nil
    end
  end
  
  describe ".permission_mask" do
    it 'should accept an integer value' do
      expect(_h.permission_mask(0x00100010)).to eq(0x00100010)
    end
    
    it "should support class instances" do
      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register

      pl = [ mp1, mp2 ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit)

      pl = [ mp1, mp2, mp5 ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit | mp3.bit)

      pl = [ mp1, mp5, mp6 ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit | mp3.bit)
    end

    it "should support names" do
      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register

      pl = [ mp1.name, mp2 ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit)

      pl = [ mp1, mp2.name.to_s, mp5.name.to_s ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit | mp3.bit)

      pl = [ mp1.name, mp5.name, mp6.name ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit | mp3.bit)
    end

    it "should support classes" do
      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register

      pl = [ mp1.class, TestAccess::P2 ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit)

      pl = [ mp1.name, mp2.class, TestAccess::P5 ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit | mp3.bit)

      pl = [ mp1.class, mp5.class, mp6.class ]
      expect(_h.permission_mask(pl)).to eql(mp1.bit | mp2.bit | mp3.bit)
    end

    it "should convert arguments to array" do
      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register

      expect(_h.permission_mask(mp1)).to eql(mp1.bit)
      expect(_h.permission_mask(TestAccess::P5)).to eql(mp1.bit | mp2.bit | mp3.bit)
      expect(_h.permission_mask(mp6.name)).to eql(mp1.bit | mp2.bit | mp3.bit)
    end

    it "should supprt mixed arrays" do
      mp1 = TestAccess::P1.new.register
      mp2 = TestAccess::P2.new.register
      mp3 = TestAccess::P3.new.register
      mp4 = TestAccess::P4.new.register
      mp5 = TestAccess::P5.new.register
      mp6 = TestAccess::P6.new.register

      pl = [ 0x00100000, mp1, mp2.name, TestAccess::P5 ]
      expect(_h.permission_mask(pl)).to eql(0x00100000 | mp1.bit | mp2.bit | mp3.bit)
    end
  end
end
