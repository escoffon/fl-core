class TestClassOne
  # Even ids find the object, odd ids fail
  
  def self.find(id)
    if (id.to_i % 2) == 0
      TestClassOne.new(id)
    else
      raise "not found"
    end
  end

  attr_reader :id

  def initialize(id)
    @id = id.to_i
  end
end

class TestClassSubOne < TestClassOne
  # Even ids find the object, odd ids fail
  
  def self.find(id)
    if (id.to_i % 2) == 0
      TestClassSubOne.new(id)
    else
      raise "not found"
    end
  end
end

class TestClassTwo
  # Even ids find the object, odd ids fail
  
  def self.find(id)
    if (id.to_i % 2) == 0
      TestClassTwo.new(id)
    else
      raise "not found"
    end
  end

  attr_reader :id

  def initialize(id)
    @id = id.to_i
  end
end

class TestClassFour
  include Fl::Core::ParametersHelper

  attr_reader :obj

  def initialize(params)
    @obj = object_from_parameter(params, :obj, [ TestClassOne ])
  end
end

class TestClassSix
  include Fl::Core::ParametersHelper

  attr_reader :obj

  def initialize(params)
    @obj = object_from_parameter(params, :obj, Proc.new { |obj| obj.is_a?(TestClassTwo) })
  end
end

RSpec.describe Fl::Core::ParametersHelper do
  let(:ph) { Fl::Core::ParametersHelper }
  let(:o10) { TestClassOne.new(10) }
  let(:o11) { TestClassOne.new(11) }
  let(:o12) { TestClassOne.new(12) }
  let(:o13) { TestClassOne.new(13) }
  let(:o20) { TestClassTwo.new(20) }
  let(:o21) { TestClassTwo.new(21) }

  describe('.object_from_parameters') do
    it('should return object instances as is') do
      f = ph.object_from_parameter(o10)
      expect(f).to be_a(TestClassOne)
      expect(f.id).to eql(o10.id)

      f = ph.object_from_parameter(o11)
      expect(f).to be_a(TestClassOne)
      expect(f.id).to eql(o11.id)
    end

    describe('with fingerprint input') do
      it('should parse fingerprints') do
        f = ph.object_from_parameter('TestClassOne/10')
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(10)
      end

      it('should raise a conversion error on malformed fingerprints') do
        expect do
          f = ph.object_from_parameter('/10')
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

        expect do
          f = ph.object_from_parameter('TestClassOne')
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

        expect do
          f = ph.object_from_parameter('TestClassOne/foo')
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end

      it('should raise a conversion error on unknown class') do
        expect do
          f = ph.object_from_parameter('Unknown/10')
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end

      it('should raise a conversion error on unknown instance') do
        expect do
          f = ph.object_from_parameter('TestClassOne/11')
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end
    end

    describe('with GlobalID input') do
      it 'should return an object on a valid ID' do
        o1 = Fl::Core::TestDatumOne.create(title: 'plain title', content: 'plain content')
        gid1 = o1.to_global_id

        o = ph.object_from_parameter(gid1)
        expect(o.fingerprint).to eql(o1.fingerprint)

        o = ph.object_from_parameter(gid1.to_s)
        expect(o.fingerprint).to eql(o1.fingerprint)
      end

      it 'should raise a conversion error exception on an invalid GlobalID' do
        expect do
          ph.object_from_parameter('gid://foo')
        end.to raise_exception(Fl::Core::ParametersHelper::ConversionError)
      end        

      it 'should succeed with an unknown app name' do
        o1 = Fl::Core::TestDatumOne.create(title: 'plain title', content: 'plain content')
        gid1 = o1.to_global_id

        uri = gid1.uri.dup
        uri.host = 'a.different.app'
        o = ph.object_from_parameter(uri.to_s)
        expect(o.fingerprint).to eql(o1.fingerprint)
      end

      it 'should raise a conversion error exception on an unknown class name' do
        o1 = Fl::Core::TestDatumOne.create(title: 'plain title', content: 'plain content')
        gid1 = o1.to_global_id

        uri = gid1.uri.dup
        uri.path = '/Fl::Core::NoSuchTestDatumOne/1'
        expect do
          o = ph.object_from_parameter(uri.to_s)
        end.to raise_exception(Fl::Core::ParametersHelper::ConversionError)
      end

      it 'should raise a conversion error exception on an unknown object' do
        o1 = Fl::Core::TestDatumOne.create(title: 'plain title', content: 'plain content')
        gid1 = o1.to_global_id

        uri = gid1.uri.dup
        uri.path = '/Fl::Core::TestDatumOne/0'
        expect do
          o = ph.object_from_parameter(uri.to_s)
        end.to raise_exception(Fl::Core::ParametersHelper::ConversionError)
      end        
    end
    
    describe('with hash input') do
      it('should raise a conversion error on a missing key') do
        expect do
          f = ph.object_from_parameter({ obj: "TestClassOne/#{o10.id}" }, :v)
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end

      describe('if key is present') do
        it('should return object value as is') do
          f = ph.object_from_parameter({ obj: o10 }, :obj)
          expect(f).to be_a(TestClassOne)
          expect(f.id).to eql(o10.id)

          f = ph.object_from_parameter({ obj: o10, v: o11 }, :v)
          expect(f).to be_a(TestClassOne)
          expect(f.id).to eql(o11.id)
        end

        describe('with fingerprint value') do
          it('should convert a fingerprint') do
            f = ph.object_from_parameter({ obj: "TestClassOne/#{o10.id}" }, :obj)
            expect(f).to be_a(TestClassOne)
            expect(f.id).to eql(o10.id)

            f = ph.object_from_parameter({
                                           obj: "TestClassOne/#{o10.id}",
                                           v: "TestClassOne/#{o12.id}"
                                         }, :v)
            expect(f).to be_a(TestClassOne)
            expect(f.id).to eql(o12.id)
          end

          it('should raise a conversion error on malformed fingerprints') do
            expect do
              f = ph.object_from_parameter({ obj: '/10' }, :obj)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

            expect do
              f = ph.object_from_parameter({ fp: 'TestClassOne' }, :fp)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

            expect do
              f = ph.object_from_parameter({ v: 'TestClassOne/foo' }, :v)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end

          it('should raise a conversion error on unknown class') do
            expect do
              f = ph.object_from_parameter({ o: 'Unknown/10' }, :o)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end

          it('should raise a conversion error on unknown instance') do
            expect do
              f = ph.object_from_parameter({ v: 'TestClassOne/11' }, :v)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end
        end

        describe('with :type/:id value') do
          it('should find the object') do
            f = ph.object_from_parameter({ type: "TestClassOne", id: o10.id })
            expect(f).to be_a(TestClassOne)
            expect(f.id).to eql(o10.id)

            f = ph.object_from_parameter({ type: "TestClassOne", id: "#{o10.id}" })
            expect(f).to be_a(TestClassOne)
            expect(f.id).to eql(o10.id)
          end

          it('should ignore the :key argument') do
            f = ph.object_from_parameter({ type: "TestClassOne", id: o10.id }, :obj)
            expect(f).to be_a(TestClassOne)
            expect(f.id).to eql(o10.id)
          end
          
          it('should raise a conversion error on missing :type or :id') do
            expect do
              f = ph.object_from_parameter({ type: "TestClassOne" })
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

            expect do
              f = ph.object_from_parameter({ id: o10.id })
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end

          it('should raise a conversion error on unknown class') do
            expect do
              f = ph.object_from_parameter({ type: "Unknown", id: 10 })
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end

          it('should raise a conversion error on unknown instance') do
            expect do
              f = ph.object_from_parameter({ type: "TestClassOne", id: 13 })
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end
        end

        describe('with hash value') do
          it('should find the object') do
            f = ph.object_from_parameter({ obj: { type: "TestClassOne", id: o10.id } }, :obj)
            expect(f).to be_a(TestClassOne)
            expect(f.id).to eql(o10.id)

            f = ph.object_from_parameter({ obj: { type: "TestClassOne", id: "#{o10.id}" } }, :obj)
            expect(f).to be_a(TestClassOne)
            expect(f.id).to eql(o10.id)
          end

          it('should raise a conversion error on missing key') do
            expect do
              f = ph.object_from_parameter({ obj: { type: "TestClassOne", id: "#{o10.id}" } }, :k)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end
          
          it('should raise a conversion error on missing :type or :id') do
            expect do
              f = ph.object_from_parameter({ o: { type: "TestClassOne" } }, :o)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

            expect do
              f = ph.object_from_parameter({ h: { id: o10.id } }, :h)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end

          it('should raise a conversion error on unknown class') do
            expect do
              f = ph.object_from_parameter({ v: { type: "Unknown", id: 10 } }, :v)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end

          it('should raise a conversion error on unknown instance') do
            expect do
              f = ph.object_from_parameter({ h: { type: "TestClassOne", id: 13 } }, :h)
            end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
          end
        end
      end
    end

    describe('with the :expect argument') do
      it('should accept a single class') do
        f = ph.object_from_parameter("TestClassOne/#{o10.id}", nil, TestClassOne)
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        f = ph.object_from_parameter("TestClassOne/#{o10.id}", :v, TestClassOne)
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        f = ph.object_from_parameter("TestClassOne/#{o10.id}", nil, 'TestClassOne')
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        expect do
          f = ph.object_from_parameter("TestClassOne/#{o10.id}", nil, TestClassTwo)
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end

      it('should accept an array of classes') do
        f = ph.object_from_parameter("TestClassOne/#{o10.id}", :v, [ TestClassOne, TestClassTwo ])
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        f = ph.object_from_parameter("TestClassOne/#{o10.id}", :v, [ 'TestClassOne', TestClassTwo ])
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        f = ph.object_from_parameter("TestClassOne/#{o10.id}", :v, [ TestClassOne, 'TestClassTwo' ])
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        expect do
          f = ph.object_from_parameter("TestClassOne/#{o10.id}", nil, [ TestClassTwo ])
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end

      it('should accept a Proc') do
        p = Proc.new { |o| o.is_a?(TestClassOne) }
        
        f = ph.object_from_parameter("TestClassOne/#{o10.id}", :v, p)
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        expect do
          f = ph.object_from_parameter("TestClassTwo/20", nil, p)
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end
    end
    
    describe('with the :strict argument') do
      it('should accept a single class') do
        f = ph.object_from_parameter("TestClassOne/#{o10.id}", nil, TestClassOne, false)
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        f = ph.object_from_parameter("TestClassSubOne/100", nil, TestClassSubOne, false)
        expect(f).to be_a(TestClassSubOne)
        expect(f.id).to eql(100)

        f = ph.object_from_parameter("TestClassOne/#{o10.id}", nil, TestClassOne, true)
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        expect do
          f = ph.object_from_parameter("TestClassSubOne/100", nil, TestClassOne, true)
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end

      it('should accept an array of classes') do
        f = ph.object_from_parameter("TestClassOne/#{o10.id}", :v, [ TestClassOne, TestClassTwo ], false)
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        f = ph.object_from_parameter("TestClassOne/#{o10.id}", :v, [ TestClassOne, TestClassTwo ], true)
        expect(f).to be_a(TestClassOne)
        expect(f.id).to eql(o10.id)

        f = ph.object_from_parameter("TestClassSubOne/100", :v, [ TestClassOne, TestClassTwo ], false)
        expect(f).to be_a(TestClassSubOne)
        expect(f.id).to eql(100)

        expect do
          f = ph.object_from_parameter("TestClassSubOne/100", :v, [ TestClassOne, TestClassTwo ], true)
        end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
      end
    end
  end

  describe('#object_from_parameters') do
    it('should resolve object') do
      f = TestClassFour.new(o10)
      expect(f.obj).to be_a(TestClassOne)
      expect(f.obj.id).to eql(o10.id)

      f = TestClassFour.new('TestClassOne/10')
      expect(f.obj).to be_a(TestClassOne)
      expect(f.obj.id).to eql(10)

      f = TestClassFour.new({ obj: 'TestClassOne/10' })
      expect(f.obj).to be_a(TestClassOne)
      expect(f.obj.id).to eql(10)

      f = TestClassSix.new(o20)
      expect(f.obj).to be_a(TestClassTwo)
      expect(f.obj.id).to eql(o20.id)

      f = TestClassSix.new('TestClassTwo/20')
      expect(f.obj).to be_a(TestClassTwo)
      expect(f.obj.id).to eql(20)

      f = TestClassSix.new({ obj: 'TestClassTwo/20' })
      expect(f.obj).to be_a(TestClassTwo)
      expect(f.obj.id).to eql(20)
    end

    it('should raise a conversion error on incorrect object') do
      expect do
        f = TestClassFour.new(o20)
      end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

      expect do
        f = TestClassFour.new("TestClassTwo/20")
      end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

      expect do
        f = TestClassSix.new(o10)
      end.to raise_error(Fl::Core::ParametersHelper::ConversionError)

      expect do
        f = TestClassSix.new("TestClassOne/10")
      end.to raise_error(Fl::Core::ParametersHelper::ConversionError)
    end
  end
end
