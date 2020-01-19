require 'rails_helper'
require 'test_permission_classes'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
  c.include Fl::Core::Test::AccessHelpers
end

class ASTestAccessCheckerOne < Fl::Core::Access::Checker
  def initialize()
    super()
  end

  def configure(base)
    base.send(:class_variable_set, :@@_test_access_checker_one, true)
    base.class_eval do
      def self.access_one_class_method()
        'access one class'
      end

      def access_one_instance_method()
        'access one instance'
      end
    end
  end

  def access_check(permission, actor, asset, context = nil)
    sp = permission.to_sym
    return true if actor.fingerprint == asset.owner.fingerprint
    
    case sp
    when Fl::Core::Access::Permission::Read::NAME
      if actor.name =~ /reader/
        true
      else
        nil
      end
    when Fl::Core::Access::Permission::Write::NAME
      if actor.name =~ /writer/
        true
      else
        nil
      end
    else
      nil
    end
  end
end

class ASTestAccessCheckerTwo < Fl::Core::Access::Checker
  def initialize()
    super()
  end

  def access_check(permission, actor, asset, context = nil)
    sp = Fl::Core::Access::Permission.lookup(permission)
    return nil if sp.nil?
    return sp.name if actor.fingerprint == asset.owner.fingerprint

    sl = [ sp ] | sp.expand_grants
    sl.each do |s|
      case s.name
      when Fl::Core::Access::Permission::Read::NAME
        return true if actor.name =~ /reader/
      when Fl::Core::Access::Permission::Write::NAME
        return true if actor.name =~ /writer/
      end
    end

    nil
  end
end

# This class definition adds access methods in one shot

class ASTestAccessDatumOne
  include Fl::Core::Access::Access

  has_access_control ASTestAccessCheckerOne.new()

  attr_reader :owner
  attr_accessor :title
  attr_accessor :value
  
  def initialize(owner, title, value)
    @owner = owner
    @title = title
    @value = value
  end
end

# This class definition adds access methods in two shots; it is how one would add access control
# to an existing class (for example, for Fl::Core::List::List)

class ASTestAccessDatumTwo
  attr_reader :owner
  attr_accessor :title
  attr_accessor :value
  
  def initialize(owner, title, value)
    @owner = owner
    @title = title
    @value = value
  end
end

class ASTestAccessDatumTwo
  include Fl::Core::Access::Access

  has_access_control ASTestAccessCheckerTwo.new()
end

RSpec.describe Fl::Core::Access::Access do
  describe ".has_access_control" do
    it 'should register the access control methods' do
      o1 = create(:test_actor, name: 'owner')
      d1 = ASTestAccessDatumOne.new(o1, 'd1 title', 'd1')
      d2 = ASTestAccessDatumTwo.new(o1, 'd2 title', 'd2')

      expect(ASTestAccessDatumOne.methods).to include(:has_access_control, :has_access_control?,
                                                    :access_checker, :has_permission?)
      expect(ASTestAccessDatumOne.instance_methods).to include(:access_checker, :has_permission?)
      expect(d1.methods).to include(:access_checker, :has_permission?)

      expect(ASTestAccessDatumOne.access_checker).to be_an_instance_of(ASTestAccessCheckerOne)
      expect(d1.access_checker).to be_an_instance_of(ASTestAccessCheckerOne)

      expect(ASTestAccessDatumTwo.access_checker).to be_an_instance_of(ASTestAccessCheckerTwo)
      expect(d2.access_checker).to be_an_instance_of(ASTestAccessCheckerTwo)
    end

    it "should modify class under checker's control" do
      expect(ASTestAccessDatumOne.class_variables).to include(:@@_test_access_checker_one)
      expect(ASTestAccessDatumOne.class_variable_get(:@@_test_access_checker_one)).to eql(true)
      expect(ASTestAccessDatumOne.methods).to include(:access_one_class_method)
      expect(ASTestAccessDatumOne.access_one_class_method).to eql('access one class')
      o1 = create(:test_actor, name: 'owner')
      d1 = ASTestAccessDatumOne.new(o1, 'd1 title', 'd1')
      expect(d1.respond_to?(:access_one_instance_method)).to eql(true)
      expect(d1.access_one_instance_method).to eql('access one instance')
    end
  end

  # We mostly check that the correct access checker is called; the behavior of the Checker#access_check
  # method is tested in checker_spec.rb
  
  describe ".has_permission?" do
    it "should grant or deny permission correctly" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d1 = ASTestAccessDatumOne.new(o1, 'd1 title', 'd1')

      g = d1.has_permission?(Fl::Core::Access::Permission::Read::NAME, r1)
      expect(g).to eql(true)
      g = d1.has_permission?(Fl::Core::Access::Permission::Read::NAME, w1)
      expect(g).to eql(true)

      g = d1.has_permission?(Fl::Core::Access::Permission::Write::NAME, r1)
      expect(g).to be_nil
      g = d1.has_permission?(Fl::Core::Access::Permission::Write::NAME, w1)
      expect(g).to eql(true)
    end

    it "should grant permission correctly using forward grants" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d2 = ASTestAccessDatumTwo.new(o1, 'd2 title', 'd2')

      g = d2.has_permission?(Fl::Core::Access::Permission::Read::NAME, r1)
      expect(g).to eql(true)
      g = d2.has_permission?(Fl::Core::Access::Permission::Read::NAME, w1)
      expect(g).to eql(true)

      g = d2.has_permission?(Fl::Core::Access::Permission::Write::NAME, r1)
      expect(g).to be_nil
      g = d2.has_permission?(Fl::Core::Access::Permission::Write::NAME, w1)
      expect(g).to eql(true)
    end

    it "should deny permission for unknown permission" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      d1 = ASTestAccessDatumOne.new(o1, 'd1 title', 'd1')

      g = d1.has_permission?(:unknown, r1)
      expect(g).to be_nil
    end
  end

  describe "#access_checker=" do
    it "should install a custom checker" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d1 = ASTestAccessDatumOne.new(o1, 'd1 title', 'd1')

      g = d1.has_permission?(Fl::Core::Access::Permission::Read::NAME, r1)
      expect(g).to eql(true)

      g = d1.has_permission?(Fl::Core::Access::Permission::Write::NAME, r1)
      expect(g).to be_nil

      d1.access_checker = Fl::Core::Access::NullChecker.new

      g = d1.has_permission?(Fl::Core::Access::Permission::Read::NAME, r1)
      expect(g).to eql(true)

      g = d1.has_permission?(Fl::Core::Access::Permission::Write::NAME, r1)
      expect(g).to eql(true)

      d10 = ASTestAccessDatumOne.new(o1, 'd10 title', 'd10')

      g = d10.has_permission?(Fl::Core::Access::Permission::Read::NAME, r1)
      expect(g).to eql(true)

      g = d10.has_permission?(Fl::Core::Access::Permission::Write::NAME, r1)
      expect(g).to be_nil
    end
  end
end
