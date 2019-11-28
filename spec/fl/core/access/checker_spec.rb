require 'rails_helper'
require 'test_permission_classes'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
  c.include Fl::Core::Test::AccessHelpers
end

class TestAccessCheckerOne < Fl::Core::Access::Checker
  def initialize()
    super()
  end

  def access_check(permission, actor, asset, context = nil)
    sp = permission.to_sym
    return sp if actor.fingerprint == asset.owner.fingerprint
    
    case sp
    when Fl::Core::Access::Permission::Read::NAME
      if actor.name =~ /reader/
        Fl::Core::Access::Permission::Read::NAME
      else
        nil
      end
    when Fl::Core::Access::Permission::Write::NAME
      if actor.name =~ /writer/
        Fl::Core::Access::Permission::Write::NAME
      else
        nil
      end
    else
      nil
    end
  end
end

class TestAccessCheckerTwo < Fl::Core::Access::Checker
  def initialize()
    super()
  end

  def access_check(permission, actor, asset, context = nil)
    sp = permission.to_sym
    return sp if actor.fingerprint == asset.owner.fingerprint

    # not the best access check, because a 'reader only' actor will be granted write access, but
    # good enough for testing.
    
    sl = [ sp ] | Fl::Core::Access::Permission.grantors_for_permission(sp)
    sl.each do |s|
      case s
      when Fl::Core::Access::Permission::Edit::NAME
        return s if actor.name =~ /(reader)|(writer)/
      end
    end

    nil
  end
end

class TestAccessDatumOne
  include Fl::Core::Access::Access

  has_access_control TestAccessCheckerOne.new()

  attr_reader :owner
  attr_accessor :title
  attr_accessor :value
  
  def initialize(owner, title, value)
    @owner = owner
    @title = title
    @value = value
  end
end

class TestAccessDatumTwo
  include Fl::Core::Access::Access

  has_access_control TestAccessCheckerTwo.new()

  attr_reader :owner
  attr_accessor :title
  attr_accessor :value
  
  def initialize(owner, title, value)
    @owner = owner
    @title = title
    @value = value
  end
end

RSpec.describe Fl::Core::Access::Checker, type: :model do
  describe "#access_check" do
    it "should grant or deny permission correctly" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d1 = TestAccessDatumOne.new(o1, 'd1 title', 'd1')

      checker = TestAccessDatumOne.access_checker

      g = checker.access_check(Fl::Core::Access::Permission::Read::NAME, r1, d1)
      expect(g).to eql(Fl::Core::Access::Permission::Read::NAME)
      g = checker.access_check(Fl::Core::Access::Permission::Read::NAME, w1, d1)
      expect(g).to eql(Fl::Core::Access::Permission::Read::NAME)

      g = checker.access_check(Fl::Core::Access::Permission::Write::NAME, r1, d1)
      expect(g).to be_nil
      g = checker.access_check(Fl::Core::Access::Permission::Write::NAME, w1, d1)
      expect(g).to eql(Fl::Core::Access::Permission::Write::NAME)
    end

    it "should grant permission correctly using forward grants" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d2 = TestAccessDatumTwo.new(o1, 'd2 title', 'd2')

      checker = TestAccessDatumTwo.access_checker

      g = checker.access_check(Fl::Core::Access::Permission::Read::NAME, r1, d2)
      expect(g).to eql(Fl::Core::Access::Permission::Edit::NAME)
      g = checker.access_check(Fl::Core::Access::Permission::Read::NAME, w1, d2)
      expect(g).to eql(Fl::Core::Access::Permission::Edit::NAME)

      g = checker.access_check(Fl::Core::Access::Permission::Write::NAME, r1, d2)
      expect(g).to eql(Fl::Core::Access::Permission::Edit::NAME)
      g = checker.access_check(Fl::Core::Access::Permission::Write::NAME, w1, d2)
      expect(g).to eql(Fl::Core::Access::Permission::Edit::NAME)
    end

    it "should deny permission for unknown permission" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      d1 = TestAccessDatumOne.new(o1, 'd1 title', 'd1')

      checker = TestAccessDatumOne.access_checker
      g = checker.access_check(:unknown, r1, d1)
      expect(g).to be_nil
    end
  end
end
