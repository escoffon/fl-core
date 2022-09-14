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

class TestRelation
  attr_reader :last_includes
  attr_reader :last_clause
  attr_reader :last_params
  attr_reader :id
  attr_reader :saw_none
  
  def initialize(id)
    @id = id
    reset()
  end

  def reset()
    @last_includes = nil
    @last_clause = nil
    @last_params = nil
    @saw_none = false
  end

  def includes(inc)
    @last_includes = inc
    return self
  end

  def where(clause, params)
    @last_clause = clause
    @last_params = params
  end

  #def none()
  #  @saw_none = true
  #end
end

class TestFilter < Fl::Core::Query::Filter
  def initialize(cfg, other)
    @other = 10
    super(cfg)
  end
end

RSpec.describe Fl::Core::Query::QueryHelper do
  let(:qh) { Fl::Core::Query::QueryHelper }

  let(:default_order) { [ 'updated_at DESC' ] }

  let(:q1) { TestQuery.new }
  let(:q2) { TestQuery.new }
  let(:q3) { TestQuery.new }
  let(:q4) { TestQuery.new }

  let(:cfg_1) do
    {
      filters: {
        ones: {
          type: :references,
          field: 'c_one',
          class_name: 'Fl::Core::TestDatumOne',
          convert: :id
        },

        polys: {
          type: :polymorphic_references,
          field: 'c_poly',
          convert: :fingerprint
        },

        blocked: {
          type: :block_list,
          field: 'c_blocked',
          convert: Proc.new { |filter, list, type| list.map { |e| e * 10 } }
        }
      }
    }
  end

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

  describe '.generate_order_clause' do
    context 'with string argument' do
      it 'should generate a single axis option' do
        c = qh.generate_order_clause({ order: 'mycol ASC' })
        expect(c).to eql(' ORDER BY mycol ASC')
      end

      it 'should generate a multi axis option' do
        c = qh.generate_order_clause({ order: 'mycol ASC, ocol DESC' })
        expect(c).to eql(' ORDER BY mycol ASC, ocol DESC')
      end

      it 'should not generate with an empty string' do
        c = qh.generate_order_clause({ order: '' })
        expect(c).to eql('')
      end
    end
    
    context 'with array argument' do
      it 'should generate a single axis option' do
        c = qh.generate_order_clause({ order: [ 'mycol ASC' ] })
        expect(c).to eql(' ORDER BY mycol ASC')
      end

      it 'should generate a multi axis option' do
        c = qh.generate_order_clause({ order: [ 'mycol ASC', 'ocol DESC' ] })
        expect(c).to eql(' ORDER BY mycol ASC, ocol DESC')
      end

      it 'should not generate with an empty array' do
        c = qh.generate_order_clause({ order: [ ] })
        expect(c).to eql('')
      end
    end
    
    context 'with false argument' do
      it 'should not generate a clause' do
        c = qh.generate_order_clause({ order: false })
        expect(c).to eql('')
      end
    end
    
    context 'with nil argument' do
      it 'should generate a backstop if the default is missing' do
        c = qh.generate_order_clause({ order: nil })
        expect(c).to eql(" ORDER BY #{default_order.join(', ')}")
      end

      it 'should normalize a default string' do
        c = qh.generate_order_clause({ order: nil }, '   mycol   ASC  ,   alsocol  DESC   ')
        expect(c).to eql(" ORDER BY mycol ASC, alsocol DESC")
      end

      it 'should convert a default array to a string' do
        c = qh.generate_order_clause({ order: nil }, [ '   mycol   ASC  ',  '  alsocol  DESC   ' ])
        expect(c).to eql(" ORDER BY mycol ASC, alsocol DESC")
      end
    end
    
    context 'with missing argument' do
      it 'should return a backstop if the default is missing' do
        c = qh.generate_order_clause({ })
        expect(c).to eql(" ORDER BY #{default_order.join(', ')}")
      end

      it 'should normalize a default string' do
        c = qh.generate_order_clause({ }, '   mycol   ASC  ,   alsocol  DESC   ')
        expect(c).to eql(" ORDER BY mycol ASC, alsocol DESC")
      end

      it 'should convert a default array to a string' do
        c = qh.generate_order_clause({ }, [ '   mycol   ASC  ',  '  alsocol  DESC   ' ])
        expect(c).to eql(" ORDER BY mycol ASC, alsocol DESC")
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

  describe '.generate_offset_clause' do
    it 'should generate the option if non-nil' do
      c = qh.generate_offset_clause({ offset: 10 })
      expect(c).to eql(" OFFSET 10")

      c = qh.generate_offset_clause({ offset: '10' })
      expect(c).to eql(" OFFSET 10")
    end

    it 'should not generate the option if nil' do
      c = qh.generate_offset_clause({ offset: nil })
      expect(c).to eql('')
    end

    it 'should not generate the option if negative' do
      c = qh.generate_offset_clause({ offset: -10 })
      expect(c).to eql('')

      c = qh.generate_offset_clause({ offset: '-10' })
      expect(c).to eql('')
    end

    it 'should not generate the option if not present' do
      c = qh.generate_offset_clause({ })
      expect(c).to eql('')
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

  describe '.generate_limit_clause' do
    it 'should generate the option if non-nil' do
      c = qh.generate_limit_clause({ limit: 10 })
      expect(c).to eql(" LIMIT 10")

      c = qh.generate_limit_clause({ limit: '10' })
      expect(c).to eql(" LIMIT 10")
    end

    it 'should generate add the option if nil' do
      c = qh.generate_limit_clause({ limit: nil })
      expect(c).to eql('')
    end

    it 'should not add the option if negative' do
      c = qh.generate_limit_clause({ limit: -10 })
      expect(c).to eql('')

      c = qh.generate_limit_clause({ limit: '-10' })
      expect(c).to eql('')
    end

    it 'should not add the option if not present' do
      c = qh.generate_limit_clause({ })
      expect(c).to eql('')
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

  describe '.adjust_includes' do
    context 'with a scalar argument' do
      it 'should return an empty array with a nil argument' do
        expect(qh.adjust_includes(nil)).to eql([ ])
      end
    
      it 'should return an empty array with a false argument' do
        expect(qh.adjust_includes(false)).to eql([ ])
      end
    
      it 'should convert a symbol to a one-element array' do
        expect(qh.adjust_includes(:one)).to eql([ :one ])
      end
    
      it 'should convert a string to a one-element array' do
        expect(qh.adjust_includes('one')).to eql([ 'one' ])
      end
    
      it 'should convert a hash to a one-element array' do
        expect(qh.adjust_includes({ one: [ :two ] })).to eql([ { one: [ :two ] } ])
      end
    
      it 'should convert ActionController::Parameters to a one-element array' do
        expect(qh.adjust_includes(ActionController::Parameters.new({ one: [ :two ] }))).to eql([ { 'one' => [ :two ] } ])
      end
    end

    context 'with an array argument' do
      it 'should return symbols or strings as-is' do
        expect(qh.adjust_includes([ :one, 'two' ])).to eql([ :one, 'two' ])
      end

      it 'should return a list as-is if no attachments are detected' do
        expect(qh.adjust_includes([ :one, :two ])).to eql([ :one, :two ])

        i = [ :one,
              { two: :three },
              { four: [ :five, :six ] } ]
        x = [ :one,
              { two: [ :three ] },
              { four: [ :five, :six ] } ]
        expect(qh.adjust_includes(i)).to eql(x)
      end

      it 'should adjust a symbol attachment element' do
        i = [ :att, 'two' ]
        x = [ { att_attachment: [ :blob ] }, 'two' ]
        expect(qh.adjust_includes(i, [ :att ])).to eql(x)
      end

      it 'should accept string for attachment names' do
        i = [ :att, 'two' ]
        x = [ { att_attachment: [ :blob ] }, 'two' ]
        expect(qh.adjust_includes(i, [ 'att' ])).to eql(x)
      end

      it 'should adjust a string attachment element' do
        i = [ 'att', 'two' ]
        x = [ { att_attachment: [ :blob ] }, 'two' ]
        expect(qh.adjust_includes(i, [ :att ])).to eql(x)
      end

      it 'should recurse into hash elements' do
        i = [ :avatar,
              { sub1: [ :one, :two ] },
              { sub2: [ 'att', 'three', :four ] } ]
        x = [ { avatar_attachment: [ :blob ] },
              { sub1: [ :one, :two ] },
              { sub2: [ { att_attachment: [ :blob ] }, 'three', :four ] } ]
        expect(qh.adjust_includes(i, [ :avatar, :att ])).to eql(x)

        i = [ :avatar,
              { sub1: [ :one, :two, { six: [ :att, 'ten' ] } ] },
              { sub2: [ 'also_att', 'three', :four ] } ]
        x = [ { avatar_attachment: [ :blob ] },
              { sub1: [ :one, :two, { six: [ { att_attachment: [ :blob ] }, 'ten' ] } ] },
              { sub2: [ { also_att_attachment: [ :blob ] }, 'three', :four ] } ]
        expect(qh.adjust_includes(i, [ :avatar, 'att', :also_att ])).to eql(x)
      end

      it 'should accept ActionController::Parameters elements' do
        # The ActionController::Parameters are turned into hashes with indifferent access
      
        i = [ :avatar,
              ActionController::Parameters.new(sub1: [ :one, :two ]),
              ActionController::Parameters.new(sub2: [ :att, 'three', :four ]) ]
        x = [ { avatar_attachment: [ :blob ] },
              { 'sub1' => [ :one, :two ] },
              { 'sub2' => [ { att_attachment: [ :blob ] }, 'three', :four ] } ]
        expect(qh.adjust_includes(i, [ :avatar, :att ])).to eql(x)

        i = [ :avatar,
              ActionController::Parameters.new(sub1: [ :one, :two,
                                                       ActionController::Parameters.new(six: [ :att, 'ten' ]) ]),
              ActionController::Parameters.new(sub2: [ :also_att, 'three', :four ]) ]
        x = [ { avatar_attachment: [ :blob ] },
              { 'sub1' => [ :one, :two,
                            { 'six' => [ { att_attachment: [ :blob ] }, 'ten' ] } ] },
              { 'sub2' => [ { also_att_attachment: [ :blob ] }, 'three', :four ] } ]
        expect(qh.adjust_includes(i, [ :avatar, :att, :also_att ])).to eql(x)
      end
    end

    it 'should detect :avatar by default' do
      i = [ :avatar, 'two' ]
      x = [ { avatar_attachment: [ :blob ] }, 'two' ]
      expect(qh.adjust_includes(i)).to eql(x)
    end
  end

  describe '.add_includes' do
    it 'should return the relation' do
      q = TestRelation.new(10)
      q1 = qh.add_includes(q, nil, false)
      expect(q1).to be_a(TestRelation)
      expect(q1.id).to eql(10)
    end

    it 'should not set includes if the includes argument is false' do
      q = TestRelation.new(10)
      q1 = qh.add_includes(q, false, [ :one ])
      expect(q.last_includes).to be_nil
    end

    context 'with a non-nil includes argument' do
      it 'should ignore the defaults' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, [ :one, :two ], [ :three ])
        expect(q.last_includes).to eql([ :one, :two ])
      end

      it 'should use the default attachments list' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, [ :one, :two, :avatar ], [ :three ])
        expect(q.last_includes).to eql([ :one, :two, { avatar_attachment: [ :blob ] } ])
      end

      it 'should use the given attachments list' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, [ :one, :two, :avatar ], [ :three ], [ :one ])
        expect(q.last_includes).to eql([ { one_attachment: [ :blob ] }, :two, :avatar ])
      end
    end

    context 'with a nil includes argument' do
      it 'should use the defaults' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, nil, [ :one, :two ])
        expect(q.last_includes).to eql([ :one, :two ])
      end

      it 'should not set includes if defaults is also nil' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, nil, nil)
        expect(q.last_includes).to be_nil
      end

      it 'should not set includes if defaults is false' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, nil, false)
        expect(q.last_includes).to be_nil
      end

      it 'should not set includes if defaults is missing' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, nil)
        expect(q.last_includes).to be_nil
      end

      it 'should use the default attachments list' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, nil, [ :one, :two, :avatar ])
        expect(q.last_includes).to eql([ :one, :two, { avatar_attachment: [ :blob ] } ])
      end
      
      it 'should use the given attachments list' do
        q = TestRelation.new(10)
        q1 = qh.add_includes(q, nil, [ :one, :two, :avatar ], [ :one ])
        expect(q.last_includes).to eql([ { one_attachment: [ :blob ] }, :two, :avatar ])
      end
    end
  end

  describe '.process_filters' do
    it 'should return a nil WHERE clause if the filter argument is nil' do
      clause, params = qh.process_filters(nil, cfg_1)
      expect(clause).to be_nil
      expect(params).to be_nil
    end

    it 'should return a nil WHERE clause if the filter argument is an empty hash' do
      clause, params = qh.process_filters({ }, cfg_1)
      expect(clause).to be_nil
      expect(params).to be_nil
    end

    it 'should return a WHERE clause if filters are present' do
      clause, params = qh.process_filters({
                                            ones: {
                                              only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                                            }
                                          }, cfg_1)
      expect(clause).to eql('(c_one IN (:p1))')
      expect(params).to include(p1: [ 1, 2 ])

      clause, params = qh.process_filters({
                                            ones: {
                                              only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                                            },
                                            polys: { except: 'Fl::Core::TestDatum/1' },
                                            blocked: { only: [ 1, 2 ], except: [ 1 ] }
                                          }, cfg_1)
        expect(clause).to eql('((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))')
        expect(params).to include(p1: [ 1, 2 ],
                                  p2: [ 'Fl::Core::TestDatum/1' ],
                                  p3: [ 20 ])
    end

    it 'should accept a filter object instead of a configuration' do
      clause, params = qh.process_filters({
                                            ones: {
                                              only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                                            }
                                          }, TestFilter.new(cfg_1, 10))
      expect(clause).to eql('(c_one IN (:p1))')
      expect(params).to include(p1: [ 1, 2 ])

      clause, params = qh.process_filters({
                                            ones: {
                                              only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                                            },
                                            polys: { except: 'Fl::Core::TestDatum/1' },
                                            blocked: { only: [ 1, 2 ], except: [ 1 ] }
                                          }, TestFilter.new(cfg_1, 20))
        expect(clause).to eql('((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))')
        expect(params).to include(p1: [ 1, 2 ],
                                  p2: [ 'Fl::Core::TestDatum/1' ],
                                  p3: [ 20 ])
    end
  end

  describe '.add_filters' do
    it 'should return the relation' do
      q = TestRelation.new(10)
      q1 = qh.add_filters(q, { }, cfg_1)
      expect(q1).to be_a(TestRelation)
      expect(q1.id).to eql(10)
    end

    it 'should not set the WHERE clause if the filter argument is nil' do
      q = TestRelation.new(10)
      q1 = qh.add_filters(q, nil, cfg_1)
      expect(q.last_clause).to be_nil
      expect(q.last_params).to be_nil
    end

    it 'should not set the WHERE clause if the filter argument is an empty hash' do
      q = TestRelation.new(10)
      q1 = qh.add_filters(q, { }, cfg_1)
      expect(q.last_clause).to be_nil
      expect(q.last_params).to be_nil
    end

    it 'should generate the WHERE clause if filters are present' do
      q = TestRelation.new(10)
      
      q1 = qh.add_filters(q, { ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] } }, cfg_1)
      expect(q.last_clause).to eql('(c_one IN (:p1))')
      expect(q.last_params).to include(p1: [ 1, 2 ])

      q.reset
      q1 = qh.add_filters(q, {
                            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                            polys: { except: 'Fl::Core::TestDatum/1' },
                            blocked: { only: [ 1, 2 ], except: [ 1 ] }
                          }, cfg_1)
        expect(q.last_clause).to eql('((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))')
        expect(q.last_params).to include(p1: [ 1, 2 ],
                                         p2: [ 'Fl::Core::TestDatum/1' ],
                                         p3: [ 20 ])
    end

    it 'should accept a filter object instead of a configuration' do
      q = TestRelation.new(10)
      
      q1 = qh.add_filters(q, {
                            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] }
                          }, TestFilter.new(cfg_1, 10))
      expect(q.last_clause).to eql('(c_one IN (:p1))')
      expect(q.last_params).to include(p1: [ 1, 2 ])

      q.reset
      q1 = qh.add_filters(q, {
                            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                            polys: { except: 'Fl::Core::TestDatum/1' },
                            blocked: { only: [ 1, 2 ], except: [ 1 ] }
                          }, TestFilter.new(cfg_1, 20))
        expect(q.last_clause).to eql('((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))')
        expect(q.last_params).to include(p1: [ 1, 2 ],
                                         p2: [ 'Fl::Core::TestDatum/1' ],
                                         p3: [ 20 ])
    end
  end
end
