require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe ActiveRecord::Base, type: :model do
  let(:a1) { create(:test_actor) }
  let(:d10) { create(:test_datum_one, owner: a1, title: 'd10') }

  describe '.split_fingerprint' do
    it 'should split a well formed fingerprint' do
      cn, id = ActiveRecord::Base.split_fingerprint('Fl::Core::TestDatumOne/10')
      expect(cn).to eql('Fl::Core::TestDatumOne')
      expect(id).to eql(10)
      
      cn, id = Fl::Core::TestDatumOne.split_fingerprint('Fl::Core::TestDatumOne/10')
      expect(cn).to eql('Fl::Core::TestDatumOne')
      expect(id).to eql(10)
    end

    it 'should fail on an unknown class if asked to check' do
      cn, id = ActiveRecord::Base.split_fingerprint('BadClass/10')
      expect(cn).to eql('BadClass')
      expect(id).to eql(10)

      cn, id = ActiveRecord::Base.split_fingerprint('BadClass/10', false)
      expect(cn).to eql('BadClass')
      expect(id).to eql(10)

      cn, id = Fl::Core::TestDatumOne.split_fingerprint('BadClass/10', false)
      expect(cn).to eql('BadClass')
      expect(id).to eql(10)

      cn, id = ActiveRecord::Base.split_fingerprint('BadClass/10', true)
      expect(cn).to be_nil
      expect(id).to be_nil

      cn, id = Fl::Core::TestDatumOne.split_fingerprint('BadClass/10', true)
      expect(cn).to be_nil
      expect(id).to be_nil
    end

    it 'should fail on a malformed fingerprint' do
      cn, id = ActiveRecord::Base.split_fingerprint('BadClass/abcd')
      expect(cn).to be_nil
      expect(id).to be_nil

      cn, id = Fl::Core::TestDatumOne.split_fingerprint('BadClass/abcd')
      expect(cn).to be_nil
      expect(id).to be_nil

      cn, id = ActiveRecord::Base.split_fingerprint('MyClass')
      expect(cn).to be_nil
      expect(id).to be_nil

      cn, id = Fl::Core::TestDatumOne.split_fingerprint('MyClass')
      expect(cn).to be_nil
      expect(id).to be_nil
    end
  end

  describe '.fingerprint' do
    it 'should generate a fingerprint from a model instance' do
      expect(ActiveRecord::Base.fingerprint(d10)).to eql("Fl::Core::TestDatumOne/#{d10.id}")
      expect(Fl::Core::TestDatumOne.fingerprint(d10)).to eql("Fl::Core::TestDatumOne/#{d10.id}")
    end

    it 'should generate a fingerprint from a class/id pair' do
      expect(ActiveRecord::Base.fingerprint(Fl::Core::TestDatumOne, 20)).to eql("Fl::Core::TestDatumOne/20")
      expect(Fl::Core::TestDatumOne.fingerprint(Fl::Core::TestDatumOne, 20)).to eql("Fl::Core::TestDatumOne/20")
    end

    it 'should generate a fingerprint from an identifier' do
      expect(Fl::Core::TestDatumOne.fingerprint(20)).to eql("Fl::Core::TestDatumOne/20")
      expect(Fl::Core::TestDatumOne.fingerprint('20')).to eql("Fl::Core::TestDatumOne/20")

      expect(Fl::Core::TestDatumTwo.fingerprint(20)).to eql("Fl::Core::TestDatumTwo/20")
      expect(Fl::Core::TestDatumTwo.fingerprint('20')).to eql("Fl::Core::TestDatumTwo/20")
    end
  end

  describe '#fingerprint' do
    it 'should generate a fingerprint correctly' do
      expect(d10.fingerprint).to eql("Fl::Core::TestDatumOne/#{d10.id}")
    end
  end

  describe '.find_by_fingerprint' do
    it 'should find with a valid fingerprint' do
      o = ActiveRecord::Base.find_by_fingerprint(d10.fingerprint)
      expect(o).to be_a(d10.class)
      expect(o.id).to eql(d10.id)

      o = Fl::Core::TestDatumOne.find_by_fingerprint(d10.fingerprint)
      expect(o).to be_a(d10.class)
      expect(o.id).to eql(d10.id)

      o = Fl::Core::TestDatumTwo.find_by_fingerprint(d10.fingerprint)
      expect(o).to be_a(d10.class)
      expect(o.id).to eql(d10.id)
    end

    it 'should return nil with a well formed fingerprint to an unknown identifier' do
      o = ActiveRecord::Base.find_by_fingerprint('Fl::Core::TestDatumOne/0')
      expect(o).to be_nil

      o = Fl::Core::TestDatumOne.find_by_fingerprint('Fl::Core::TestDatumOne/0')
      expect(o).to be_nil

      o = Fl::Core::TestDatumTwo.find_by_fingerprint('Fl::Core::TestDatumOne/0')
      expect(o).to be_nil
    end

    it 'should return nil with a well formed fingerprint to an unknown class' do
      o = ActiveRecord::Base.find_by_fingerprint('MyDatumOne/10')
      expect(o).to be_nil

      o = Fl::Core::TestDatumOne.find_by_fingerprint('MyDatumOne/10')
      expect(o).to be_nil

      o = Fl::Core::TestDatumTwo.find_by_fingerprint('MyDatumOne/10')
      expect(o).to be_nil
    end

    it 'should return nil with a malformed fingerprint' do
      o = ActiveRecord::Base.find_by_fingerprint('Fl::Core::TestDatumOne/abcd')
      expect(o).to be_nil

      o = Fl::Core::TestDatumOne.find_by_fingerprint('Fl::Core::TestDatumOne/abcd')
      expect(o).to be_nil

      o = Fl::Core::TestDatumTwo.find_by_fingerprint('Fl::Core::TestDatumOne/abcd')
      expect(o).to be_nil

      o = ActiveRecord::Base.find_by_fingerprint('Fl::Core::TestDatumOne')
      expect(o).to be_nil

      o = Fl::Core::TestDatumOne.find_by_fingerprint('Fl::Core::TestDatumOne')
      expect(o).to be_nil

      o = Fl::Core::TestDatumTwo.find_by_fingerprint('Fl::Core::TestDatumOne')
      expect(o).to be_nil
    end
  end
end