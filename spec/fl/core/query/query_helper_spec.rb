class TestQuery
  attr_reader :order_clause
  attr_reader :offset_clause
  attr_reader :limit_clause

  def initialize()
    @order_clause = nil
    @offset_clause = nil
    @limit_clause = nil
  end
  
  def order(c)
    @order_clause = c
  end
  
  def offset(c)
    @offset_clause = c
  end
  
  def limit(c)
    @limit_clause = c
  end
end

RSpec.describe Fl::Core::Query::QueryHelper do
  let(:qh) { Fl::Core::Query::QueryHelper }

  let(:default_order) { [ 'updated_at DESC' ] }

  let(:q1) { TestQuery.new }
  let(:q2) { TestQuery.new }
  let(:q3) { TestQuery.new }
  let(:q4) { TestQuery.new }
  
  describe '.parse_order_options' do
    context 'with string argument' do
      it 'should parse a single axis option' do
        o = qh.parse_order_option({ order: 'mycol ASC' })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC' ])
      end

      it 'should parse a multi axis option' do
        o = qh.parse_order_option({ order: 'mycol ASC, andcol DESC' })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'andcol DESC' ])
      end

      it 'should trim whitespace' do
        o = qh.parse_order_option({ order: '           mycol          ASC             ' })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC' ])

        o = qh.parse_order_option({ order: '     mycol         ASC     ,      andcol      DESC     ' })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'andcol DESC' ])
      end

      it 'should return nil with an empty string' do
        o = qh.parse_order_option({ order: '' })
        expect(o).to be_nil
      end
    end
    
    context 'with array argument' do
      it 'should parse a single axis option' do
        o = qh.parse_order_option({ order: [ 'mycol ASC' ] })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC' ])
      end

      it 'should parse a multi axis option' do
        o = qh.parse_order_option({ order: [ 'mycol ASC', 'andcol DESC' ] })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'andcol DESC' ])
      end

      it 'should trim whitespace' do
        o = qh.parse_order_option({ order: [ '           mycol          ASC             '  ] })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC' ])

        o = qh.parse_order_option({ order: [ '   mycol  ASC   ', '   andcol      DESC     '  ] })
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'andcol DESC' ])
      end

      it 'should return nil with an empty array' do
        o = qh.parse_order_option({ order: [ ] })
        expect(o).to be_nil
      end
    end
    
    context 'with false argument' do
      it 'should return nil' do
        o = qh.parse_order_option({ order: false })
        expect(o).to be_nil
      end
    end
    
    context 'with nil argument' do
      it 'should return a backstop if the default is missing' do
        o = qh.parse_order_option({ order: nil })
        expect(o).to be_a(Array)
        expect(o).to eql(default_order)
      end

      it 'should convert a default string to array' do
        o = qh.parse_order_option({ order: nil }, '   mycol   ASC  ,   alsocol  DESC   ')
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end

      it 'should return the default array' do
        o = qh.parse_order_option({ order: nil }, [ '   mycol   ASC  ',  '  alsocol  DESC   ' ])
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end
    end
    
    context 'with missing argument' do
      it 'should return a backstop if the default is missing' do
        o = qh.parse_order_option({ })
        expect(o).to be_a(Array)
        expect(o).to eql(default_order)
      end

      it 'should convert a default string to array' do
        o = qh.parse_order_option({ }, '   mycol   ASC  ,   alsocol  DESC   ')
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end

      it 'should return the default array' do
        o = qh.parse_order_option({ }, [ '   mycol   ASC  ',  '  alsocol  DESC   ' ])
        expect(o).to be_a(Array)
        expect(o).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end
    end
  end

  describe '.add_order_clause' do
    context 'with string argument' do
      it 'should add a single axis option' do
        o = qh.add_order_clause(q1, { order: 'mycol ASC' })
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC' ])
      end

      it 'should add a multi axis option' do
        o = qh.add_order_clause(q1, { order: 'mycol ASC, ocol DESC' })
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC', 'ocol DESC' ])
      end

      it 'should not add with an empty string' do
        o = qh.add_order_clause(q1, { order: '' })
        expect(q1.order_clause).to be_nil
      end
    end
    
    context 'with array argument' do
      it 'should add a single axis option' do
        o = qh.add_order_clause(q1, { order: [ 'mycol ASC' ] })
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC' ])
      end

      it 'should add a multi axis option' do
        o = qh.add_order_clause(q1, { order: [ 'mycol ASC', 'ocol DESC' ] })
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC', 'ocol DESC' ])
      end

      it 'should not add with an empty array' do
        o = qh.add_order_clause(q1, { order: [ ] })
        expect(q1.order_clause).to be_nil
      end
    end
    
    context 'with false argument' do
      it 'should not add a clause' do
        o = qh.add_order_clause(q1, { order: false })
        expect(q1.order_clause).to be_nil
      end
    end
    
    context 'with nil argument' do
      it 'should add a backstop if the default is missing' do
        o = qh.add_order_clause(q1, { order: nil })
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql(default_order)
      end

      it 'should convert a default string to array' do
        o = qh.add_order_clause(q1, { order: nil }, '   mycol   ASC  ,   alsocol  DESC   ')
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end

      it 'should return the default array' do
        o = qh.add_order_clause(q1, { order: nil }, [ '   mycol   ASC  ',  '  alsocol  DESC   ' ])
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end
    end
    
    context 'with missing argument' do
      it 'should return a backstop if the default is missing' do
        o = qh.add_order_clause(q1, { })
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql(default_order)
      end

      it 'should convert a default string to array' do
        o = qh.add_order_clause(q1, { }, '   mycol   ASC  ,   alsocol  DESC   ')
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end

      it 'should return the default array' do
        o = qh.add_order_clause(q1, { }, [ '   mycol   ASC  ',  '  alsocol  DESC   ' ])
        expect(q1.order_clause).to be_a(Array)
        expect(q1.order_clause).to eql([ 'mycol ASC', 'alsocol DESC' ])
      end
    end
  end

  describe '.add_offset_clause' do
    it 'should add the option if non-nil' do
      o = qh.add_offset_clause(q1, { offset: 10 })
      expect(q1.offset_clause).to eql(10)

      o = qh.add_offset_clause(q2, { offset: '10' })
      expect(q2.offset_clause).to eql(10)
    end

    it 'should not add the option if nil' do
      o = qh.add_offset_clause(q1, { offset: nil })
      expect(q1.offset_clause).to be_nil
    end

    it 'should not add the option if negative' do
      o = qh.add_offset_clause(q1, { offset: -10 })
      expect(q1.offset_clause).to be_nil

      o = qh.add_offset_clause(q2, { offset: '-10' })
      expect(q2.offset_clause).to be_nil
    end

    it 'should not add the option if not present' do
      o = qh.add_offset_clause(q1, { })
      expect(q1.offset_clause).to be_nil
    end
  end

  describe '.add_limit_clause' do
    it 'should add the option if non-nil' do
      o = qh.add_limit_clause(q1, { limit: 10 })
      expect(q1.limit_clause).to eql(10)

      o = qh.add_limit_clause(q2, { limit: '10' })
      expect(q2.limit_clause).to eql(10)
    end

    it 'should not add the option if nil' do
      o = qh.add_limit_clause(q1, { limit: nil })
      expect(q1.limit_clause).to be_nil
    end

    it 'should not add the option if negative' do
      o = qh.add_limit_clause(q1, { limit: -10 })
      expect(q1.limit_clause).to be_nil

      o = qh.add_limit_clause(q2, { limit: '-10' })
      expect(q2.limit_clause).to be_nil
    end

    it 'should not add the option if not present' do
      o = qh.add_limit_clause(q1, { })
      expect(q1.limit_clause).to be_nil
    end
  end
end
