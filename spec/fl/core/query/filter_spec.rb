RSpec.describe Fl::Core::Query::Filter do
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
        },

        block2: {
          type: :block_list,
          field: 'c_block2',
          convert: Proc.new { |filter, list, type| list.map { |e| e * 2 } }
        },

        ts1: {
          type: :timestamp,
          field: 'c_ts1',
          convert: :timestamp
        },

        cstm: {
          type: :custom,
          field: 'c_custom',
          convert: :custom,
          generator: Proc.new do |g, n, d, v|
            raise Fl::Core::Query::Filter::Exception.new("missing required :foo property in #{v}") if !v[:foo]

            p = g.allocate_parameter(v[:foo].downcase)
            "(LOWER(#{d[:field]}) = :#{p})"
          end
        },

        nil_custom: {
          type: :custom,
          field: 'c_nil',
          convert: :custom,
          generator: Proc.new do |g, n, d, v|
            nil
          end
        }
      }
    }
  end

  let(:cfg_2) do
    {
      filters: {
        ones: {
          type: :references,
          field: 'c_one',
          class_name: 'Fl::Core::TestDatumOne',
          convert: :id,
          generator: Proc.new do |g, n, d, v|
            if v[:only]
              if v[:only].count == 1
                p = g.allocate_parameter(v[:only].first)
                "(c_one = :#{p})"
              else
                p = g.allocate_parameter(v[:only])
                "(c_one IN (:#{p}))"
              end
            elsif v[:except]
              if v[:except].count == 1
                p = g.allocate_parameter(v[:except].first)
                "(#{d[:field]} != :#{p})"
              else
                p = g.allocate_parameter(v[:except])
                "(c_one NOT IN (:#{p}))"
              end
            else
              nil
            end
          end          
        },

        polys: {
          type: :polymorphic_references,
          field: 'c_poly',
          convert: :fingerprint,
          generator: Proc.new do |g, n, d, v|
            if v[:only]
              if v[:only].count == 1
                p = g.allocate_parameter(v[:only].first)
                "(#{d[:field]} LIKE :#{p})"
              else
                p = g.allocate_parameter(v[:only])
                "(c_poly IN (:#{p}))"
              end
            elsif v[:except]
              if v[:except].count == 1
                p = g.allocate_parameter(v[:except].first)
                "(c_poly NOT LIKE :#{p})"
              else
                p = g.allocate_parameter(v[:except])
                "(c_poly NOT IN (:#{p}))"
              end
            else
              nil
            end
          end          
        },

        blocked: {
          type: :block_list,
          field: 'c_blocked',
          convert: Proc.new { |filter, list, type| list.map { |e| e * 10 } },
          generator: Proc.new do |g, n, d, v|
            if v[:only]
              if v[:only].count == 1
                p = g.allocate_parameter(v[:only].first)
                "(#{d[:field]} = :#{p})"
              else
                p = g.allocate_parameter(v[:only])
                "(c_blocked IN (:#{p}))"
              end
            elsif v[:except]
              if v[:except].count == 1
                p = g.allocate_parameter(v[:except].first)
                "(c_blocked != :#{p})"
              else
                p = g.allocate_parameter(v[:except])
                "(c_blocked NOT IN (:#{p}))"
              end
            else
              nil
            end
          end
        },

        ts1: {
          type: :timestamp,
          field: 'c_ts1',
          convert: :timestamp,
          generator: Proc.new do |g, n, d, v|
            if v[:special]
              p = g.allocate_parameter(v[:special].to_s)
              "(#{d[:field]} LIKE :#{p})"
            else
              g.generate_timestamp_clause(n, d, v)
            end
          end
        }
      }
    }
  end

  describe '.acceptable_body?' do
    it 'should accept a Hash' do
      expect(Fl::Core::Query::Filter.acceptable_body?({ })).to eql(true)
    end
    
    it 'should accept an ActionController::Parameters' do
      expect(Fl::Core::Query::Filter.acceptable_body?(ActionController::Parameters.new({ }))).to eql(true)
    end
    
    it 'should not accept other types' do
      expect(Fl::Core::Query::Filter.acceptable_body?(1234)).to eql(false)
      expect(Fl::Core::Query::Filter.acceptable_body?(' ')).to eql(false)
      expect(Fl::Core::Query::Filter.acceptable_body?([ ])).to eql(false)
    end
  end
  
  describe '#generate' do
    context 'with empty filters' do
      it 'should return nil' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({ })
        expect(clause).to be_nil
        expect(g1.params).to eql({ })
      end
    end

    context 'with nil filters' do
      it 'should return nil' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate(nil)
        expect(clause).to be_nil
        expect(g1.params).to eql({ })
      end
    end

    context 'with a single root filter' do
      it 'should generate a simple clause of ID references' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({ ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] } })
        expect(clause).to eql('(c_one IN (:p1))')
        expect(g1.params).to include(p1: [ 1, 2 ])

        g1.reset
        clause = g1.generate({
                               ones: {
                                 except: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                               }
                             })
        expect(clause).to eql('(c_one NOT IN (:p1))')
        expect(g1.params).to include(p1: [ 1, 2 ])

        g1.reset
        clause = g1.generate({
                               ones: {
                                 only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ],
                                 except: 1
                               }
                             })
        expect(clause).to eql('(c_one IN (:p1))')
        expect(g1.params).to include(p1: [ 2 ])
      end

      it 'should generate a simple clause of polymorphic references' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               polys: {
                                 only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                               }
                             })
        expect(clause).to eql('(c_poly IN (:p1))')
        expect(g1.params).to include(p1: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ])

        g1.reset
        clause = g1.generate({
                               polys: {
                                 except: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                               }
                             })
        expect(clause).to eql('(c_poly NOT IN (:p1))')
        expect(g1.params).to include(p1: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ])

        g1.reset
        clause = g1.generate({
                               polys: {
                                 only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ],
                                 except: [ 'Fl::Core::TestDatumOne/1' ]
                               }
                             })
        expect(clause).to eql('(c_poly IN (:p1))')
        expect(g1.params).to include(p1: [ 'Fl::Core::TestDatumOne/2' ])
      end

      it 'should generate a simple clause of mapped lists' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               blocked: {
                                 only: [ 1, 2, 3, 4 ]
                               }
                             })
        expect(clause).to eql('(c_blocked IN (:p1))')
        expect(g1.params).to include(p1: [ 10, 20, 30, 40 ])

        g1.reset
        clause = g1.generate({
                               blocked: {
                                 except: [ 2, 4, 6, 8 ]
                               }
                             })
        expect(clause).to eql('(c_blocked NOT IN (:p1))')
        expect(g1.params).to include(p1: [ 20, 40, 60, 80 ])

        g1.reset
        clause = g1.generate({
                               blocked: {
                                 only: [ 1, 2, 3, 4 ],
                                 except: [ 1, 3, 5 ]
                               }
                             })
        expect(clause).to eql('(c_blocked IN (:p1))')
        expect(g1.params).to include(p1: [ 20, 40 ])
      end

      it 'should generate an ANDed complex clause if the root is :all' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               all: {
                                 ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                 polys: { except: 'Fl::Core::TestDatum/1' },
                                 blocked: { only: [ 1, 2 ], except: [ 1 ] }
                               }
                             })
        expect(clause).to eql('((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end

      it 'should generate an ORed complex clause if the root is :any' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               any: {
                                 ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                 polys: { except: 'Fl::Core::TestDatum/1' },
                                 blocked: { only: [ 1, 2 ], except: [ 1 ] }
                               }
                             })
        expect(clause).to eql('((c_one IN (:p1)) OR (c_poly NOT IN (:p2)) OR (c_blocked IN (:p3)))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end
    end

    context 'with multiple root filters' do
      it 'should generate an ANDed complex clause if the join param is :all' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                               polys: { except: 'Fl::Core::TestDatum/1' },
                               blocked: { only: [ 1, 2 ], except: [ 1 ] }
                             }, :all)
        expect(clause).to eql('((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end

      it 'should generate an ORed complex clause if the join param is :any' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                               polys: { except: 'Fl::Core::TestDatum/1' },
                               blocked: { only: [ 1, 2 ], except: [ 1 ] }
                             }, :any)
        expect(clause).to eql('((c_one IN (:p1)) OR (c_poly NOT IN (:p2)) OR (c_blocked IN (:p3)))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end

      it 'should generate an ANDed complex clause by default' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                               polys: { except: 'Fl::Core::TestDatum/1' },
                               blocked: { only: [ 1, 2 ], except: [ 1 ] }
                             })
        expect(clause).to eql('((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3)))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end
    end

    context 'with multi-level filters' do
      it 'should nest correctly from a single root (3 levels)' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               any: {
                                 ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                 all: {
                                   polys: { except: 'Fl::Core::TestDatum/1' },
                                   blocked: { only: [ 1, 2 ], except: [ 1 ] }
                                 }
                               }
                             })
        expect(clause).to eql('((c_one IN (:p1)) OR ((c_poly NOT IN (:p2)) AND (c_blocked IN (:p3))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end

      it 'should nest correctly from a multiple root (2 levels)' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                               all: {
                                 polys: { except: 'Fl::Core::TestDatum/1' },
                                 blocked: { only: [ 1, 2 ], except: [ 1 ] }
                               }
                             }, :any)
        expect(clause).to eql('((c_one IN (:p1)) OR ((c_poly NOT IN (:p2)) AND (c_blocked IN (:p3))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end

      it 'should nest correctly from a single root (4 levels)' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               any: {
                                 ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                 all: {
                                   polys: { except: 'Fl::Core::TestDatum/1' },
                                   any: {
                                     blocked: { only: [ 1, 2 ], except: [ 1 ] },
                                     block2: { only: [ 3, 5 ] }
                                   }
                                 }
                               }
                             })
        expect(clause).to eql('((c_one IN (:p1)) OR ((c_poly NOT IN (:p2)) AND ((c_blocked IN (:p3)) OR (c_block2 IN (:p4)))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ],
                                     p4: [ 6, 10 ])
      end

      it 'should nest correctly from a multiple root (3 levels)' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                               all: {
                                 polys: { except: 'Fl::Core::TestDatum/1' },
                                 any: {
                                   blocked: { only: [ 1, 2 ], except: [ 1 ] },
                                   block2: { only: [ 3, 5 ] }
                                 }
                               }
                             }, :any)
        expect(clause).to eql('((c_one IN (:p1)) OR ((c_poly NOT IN (:p2)) AND ((c_blocked IN (:p3)) OR (c_block2 IN (:p4)))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ],
                                     p4: [ 6, 10 ])
      end
    end

    context 'using ActionController::Parameters' do
      it 'should accept ActionController::Parameters' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        pars = ActionController::Parameters.new({
                                                  any: {
                                                    ones: { only: [ 'Fl::Core::TestDatumOne/1',
                                                                    'Fl::Core::TestDatumOne/2' ] },
                                                    all: {
                                                      polys: { except: 'Fl::Core::TestDatum/1' },
                                                      blocked: { only: [ 1, 2 ], except: [ 1 ] }
                                                    }
                                                  }
                                                })
        p = pars.permit({ any: { } })
        
        clause = g1.generate(p)
        expect(clause).to eql('((c_one IN (:p1)) OR ((c_poly NOT IN (:p2)) AND (c_blocked IN (:p3))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end
    end

    context 'with :not components' do
      it 'should invert a simple clause' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({ not: { ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] } } })
        expect(clause).to eql('(NOT (c_one IN (:p1)))')
        expect(g1.params).to include(p1: [ 1, 2 ])

        g1.reset
        clause = g1.generate({
                               not: {
                                 ones: {
                                   except: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ]
                                 }
                               }
                             })
        expect(clause).to eql('(NOT (c_one NOT IN (:p1)))')
        expect(g1.params).to include(p1: [ 1, 2 ])

        
        g1.reset
        clause = g1.generate({
                               not: {
                                 blocked: {
                                   except: [ 2, 4, 6, 8 ]
                                 }
                               }
                             })
        expect(clause).to eql('(NOT (c_blocked NOT IN (:p1)))')
        expect(g1.params).to include(p1: [ 20, 40, 60, 80 ])
      end

      it 'should invert a complex clause' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               not: {
                                 all: {
                                   ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                   polys: { except: 'Fl::Core::TestDatum/1' },
                                   blocked: { only: [ 1, 2 ], except: [ 1 ] }
                                 }
                               }
                             })
        expect(clause).to eql('(NOT ((c_one IN (:p1)) AND (c_poly NOT IN (:p2)) AND (c_blocked IN (:p3))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])

        g1.reset
        clause = g1.generate({
                               not: {
                                 any: {
                                   ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                   polys: { except: 'Fl::Core::TestDatum/1' },
                                   blocked: { only: [ 1, 2 ], except: [ 1 ] }
                                 }
                               }
                             })
        expect(clause).to eql('(NOT ((c_one IN (:p1)) OR (c_poly NOT IN (:p2)) OR (c_blocked IN (:p3))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end

      it 'should invert when part of a multi filter root' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                               not: { polys: { except: 'Fl::Core::TestDatum/1' } },
                               blocked: { only: [ 1, 2 ], except: [ 1 ] }
                             }, :all)
        expect(clause).to eql('((c_one IN (:p1)) AND (NOT (c_poly NOT IN (:p2))) AND (c_blocked IN (:p3)))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end

      it 'should invert when nested inside a clause' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               any: {
                                 ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                 all: {
                                   polys: { except: 'Fl::Core::TestDatum/1' },
                                   not: { blocked: { only: [ 1, 2 ], except: [ 1 ] } }
                                 }
                               }
                             })
        expect(clause).to eql('((c_one IN (:p1)) OR ((c_poly NOT IN (:p2)) AND (NOT (c_blocked IN (:p3)))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])

        g1.reset
        clause = g1.generate({
                               any: {
                                 ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
                                 not: {
                                   all: {
                                     polys: { except: 'Fl::Core::TestDatum/1' },
                                     not: { blocked: { only: [ 1, 2 ], except: [ 1 ] } }
                                   }
                                 }
                               }
                             })
        expect(clause).to eql('((c_one IN (:p1)) OR (NOT ((c_poly NOT IN (:p2)) AND (NOT (c_blocked IN (:p3))))))')
        expect(g1.params).to include(p1: [ 1, 2 ],
                                     p2: [ 'Fl::Core::TestDatum/1' ],
                                     p3: [ 20 ])
      end
    end
  end

  describe '#adjust' do
    context 'with a single root filter' do
      it 'should return the filter with an identity block' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] }
        }
        nf = g1.adjust(of) { |g, fk, fv| fv }
        expect(nf).to eql(of)
      end

      it 'should return a nil filter with a nil block' do
        # note that this will remove the clauses when the generate method is called
        
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] }
        }
        nf = g1.adjust(of) { |g, fk, fv| nil }
        expect(nf).to eql({ ones: nil })

        g1.reset
        clause = g1.generate(nf)
        expect(clause).to eql(nil)
      end

      it 'should adjust the filter under control of the block' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] }
        }
        xf = {
          ones: { only: [ 'Fl::Core::TestDatumOne/1' ] }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          if fk == :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)

        of = {
          blocked: { only: [ 1, 2, 3, 4 ], except: [ 1, 4, 7, 8 ] }
        }
        xf = {
          blocked: { only: [ 2, 4 ], except: [ 4, 8 ] }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          if fk == :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do |acc1, e1|
                acc1 << e1 if (e1 % 2) == 0
                acc1
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end
    end

    context 'with a multiple root filter' do
      it 'should return the filter with an identity block' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
          any: {
            blocked: { except: [ 11, 12 ] },
            polys: { only: [ 'Fl::Core::TestDatumOne/3' ] }
          }
        }
        nf = g1.adjust(of) { |g, fk, fv| fv }
        expect(nf).to eql(of)
      end

      it 'should adjust the filter under control of the block' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
          any: {
            blocked: { only: [ 21, 22 ], except: [ 11, 12, 21, 22 ] },
            polys: { only: [ 'Fl::Core::TestDatumOne/3', 'Fl::Core::TestDatumTwo/4' ] }
          }
        }
        xf = {
          ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
          any: {
            blocked: { only: [ 21 ], except: [ 11, 21 ] },
            polys: { only: [ 'Fl::Core::TestDatumTwo/4' ] }
          }
        }

        nf = g1.adjust(of) do |g, fk, fv| fv
          case fk
          when :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          when :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do |acc1, e1|
                acc1 << e1 if (e1 % 2) != 0
                acc1
              end
              acc
            end
          when :polys
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do |acc1, e1|
                acc1 << e1 if e1 =~ /Fl::Core::TestDatumTwo/
                acc1
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end
    end

    context 'with a :any component' do
      it 'should navigate to descendants from a single top level' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          any: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
            blocked: { only: [ 1, 2 ] }
          }
        }
        xf = {
          any: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
            blocked: { only: [ 1 ] }
          }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          case fk
          when :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          when :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do|acc2, ee|
                acc2 << ee if (ee % 2) != 0
                acc2
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end

      it 'should navigate to descendants from a nested level' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          any: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
            blocked: { only: [ 1, 2 ] },
            any: {
              blocked: { only: [ 10, 11, 12, 13 ] },
            }
          }
        }
        xf = {
          any: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
            blocked: { only: [ 1 ] },
            any: {
              blocked: { only: [ 11, 13 ] },
            }
          }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          case fk
          when :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          when :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do|acc2, ee|
                acc2 << ee if (ee % 2) != 0
                acc2
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end
    end

    context 'with a :all component' do
      it 'should navigate to descendants from a single top level' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          all: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
            blocked: { only: [ 1, 2 ] }
          }
        }
        xf = {
          all: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
            blocked: { only: [ 1 ] }
          }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          case fk
          when :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          when :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do|acc2, ee|
                acc2 << ee if (ee % 2) != 0
                acc2
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end

      it 'should navigate to descendants from a nested level' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          all: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
            blocked: { only: [ 1, 2 ] },
            all: {
              blocked: { only: [ 10, 11, 12, 13 ] },
            }
          }
        }
        xf = {
          all: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
            blocked: { only: [ 1 ] },
            all: {
              blocked: { only: [ 11, 13 ] },
            }
          }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          case fk
          when :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          when :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do|acc2, ee|
                acc2 << ee if (ee % 2) != 0
                acc2
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end
    end

    context 'with a :not component' do
      it 'should navigate to descendants from a single top level' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          not: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
            blocked: { only: [ 1, 2 ] }
          }
        }
        xf = {
          not: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
            blocked: { only: [ 1 ] }
          }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          case fk
          when :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          when :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do|acc2, ee|
                acc2 << ee if (ee % 2) != 0
                acc2
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end

      it 'should navigate to descendants from a nested level' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        of = {
          not: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1', 'Fl::Core::TestDatumOne/2' ] },
            blocked: { only: [ 1, 2 ] },
            not: {
              blocked: { only: [ 10, 11, 12, 13 ] },
            }
          }
        }
        xf = {
          not: {
            ones: { only: [ 'Fl::Core::TestDatumOne/1' ] },
            blocked: { only: [ 1 ] },
            not: {
              blocked: { only: [ 11, 13 ] },
            }
          }
        }
        nf = g1.adjust(of) do |g, fk, fv| fv
          case fk
          when :ones
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = [ 'Fl::Core::TestDatumOne/1' ]
              acc
            end
          when :blocked
            fv.reduce({ }) do |acc, fkvp|
              ek, ev = fkvp
              acc[ek] = ev.reduce([ ]) do|acc2, ee|
                acc2 << ee if (ee % 2) != 0
                acc2
              end
              acc
            end
          else
            fv
          end
        end
        expect(nf).to eql(xf)
      end
    end
  end

  describe 'filter types' do
    context ':references' do
      it 'should convert to object identifiers' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: {
                                 only: [ 1, 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumOne/3' ]
                               }
                             })
        expect(clause).to eql('(c_one IN (:p1))')
        expect(g1.params).to include(p1: [ 1, 2, 3 ])

        g1.reset
        clause = g1.generate({
                               ones: {
                                 only: [ 1, 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumOne/3', 4, 5 ],
                                 except: [ 1, 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumOne/3' ]
                               }
                             })
        expect(clause).to eql('(c_one IN (:p1))')
        expect(g1.params).to include(p1: [ 4, 5 ])
      end

      it 'should filter out other classes' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               ones: {
                                 only: [ 1, 'Fl::Core::TestDatumTwo/2', 'gid://flcore/Fl::Core::TestDatumTwo/3' ]
                               }
                             })
        expect(clause).to eql('(c_one IN (:p1))')
        expect(g1.params).to include(p1: [ 1 ])
      end

      it 'should use the custom generator if provided' do
        g1 = Fl::Core::Query::Filter.new(cfg_2)

        clause = g1.generate({
                               ones: {
                                 only: [ 1, 'Fl::Core::TestDatumTwo/2', 'gid://flcore/Fl::Core::TestDatumTwo/3' ]
                               }
                             })
        expect(clause).to eql('(c_one = :p1)')
        expect(g1.params).to include(p1: 1)

        g1.reset
        clause = g1.generate({
                               ones: {
                                 only: [ 2, 4 ]
                               }
                             })
        expect(clause).to eql('(c_one IN (:p1))')
        expect(g1.params).to include(p1: [ 2, 4 ])

        g1.reset
        clause = g1.generate({
                               ones: {
                                 except: [ 2 ]
                               }
                             })
        expect(clause).to eql('(c_one != :p1)')
        expect(g1.params).to include(p1: 2)

        g1.reset
        clause = g1.generate({
                               ones: {
                                 except: [ ]
                               }
                             })
        expect(clause).to eql('(c_one NOT IN (:p1))')
        expect(g1.params).to include(p1: [ ])

        g1.reset
        clause = g1.generate({
                               ones: {
                                 only: [ 2, 4 ],
                                 except: [ 2, 6 ]
                               }
                             })
        expect(clause).to eql('(c_one = :p1)')
        expect(g1.params).to include(p1: 4)
      end
    end

    context ':polymorphic_references' do
      it 'should convert to object fingerprints' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               polys: {
                                 only: [ 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumTwo/3' ]
                               }
                             })
        expect(clause).to eql('(c_poly IN (:p1))')
        expect(g1.params).to include(p1: [ 'Fl::Core::TestDatumOne/2', 'Fl::Core::TestDatumTwo/3' ])

        g1.reset
        clause = g1.generate({
                               polys: {
                                 only: [ 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumTwo/3',
                                         'gid://flcore/Fl::Core::TestDatumOne/4', 'Fl::Core::TestDatumTwo/5' ],
                                 except: [ 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumTwo/3' ]
                               }
                             })
        expect(clause).to eql('(c_poly IN (:p1))')
        expect(g1.params).to include(p1: [ 'Fl::Core::TestDatumOne/4', 'Fl::Core::TestDatumTwo/5' ])
      end

      it 'should use the custom generator if provided' do
        g1 = Fl::Core::Query::Filter.new(cfg_2)

        clause = g1.generate({
                               polys: {
                                 only: [ 'gid://flcore/Fl::Core::TestDatumTwo/3' ]
                               }
                             })
        expect(clause).to eql('(c_poly LIKE :p1)')
        expect(g1.params).to include(p1: 'Fl::Core::TestDatumTwo/3')

        g1.reset
        clause = g1.generate({
                               polys: {
                                 only: [ 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumTwo/3' ]
                               }
                             })
        expect(clause).to eql('(c_poly IN (:p1))')
        expect(g1.params).to include(p1: [ 'Fl::Core::TestDatumOne/2', 'Fl::Core::TestDatumTwo/3' ])

        g1.reset
        clause = g1.generate({
                               polys: {
                                 except: [ 'Fl::Core::TestDatumOne/2' ]
                               }
                             })
        expect(clause).to eql('(c_poly NOT LIKE :p1)')
        expect(g1.params).to include(p1: 'Fl::Core::TestDatumOne/2')

        g1.reset
        clause = g1.generate({
                               polys: {
                                 except: [ ]
                               }
                             })
        expect(clause).to eql('(c_poly NOT IN (:p1))')
        expect(g1.params).to include(p1: [ ])

        g1.reset
        clause = g1.generate({
                               polys: {
                                 only: [ 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumTwo/3',
                                         'gid://flcore/Fl::Core::TestDatumOne/4' ],
                                 except: [ 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumTwo/3' ]
                               }
                             })
        expect(clause).to eql('(c_poly LIKE :p1)')
        expect(g1.params).to include(p1: 'Fl::Core::TestDatumOne/4')
      end
    end

    context ':blocked' do
      it 'should convert according to the conversion block' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({
                               blocked: {
                                 only: [ 1, 2, 3, 4 ]
                               }
                             })
        expect(clause).to eql('(c_blocked IN (:p1))')
        expect(g1.params).to include(p1: [ 10, 20, 30, 40 ])

        g1.reset
        clause = g1.generate({
                               blocked: {
                                 only: [ 2, 3, 4, 5 ],
                                 except: [ 2, 3 ]
                               }
                             })
        expect(clause).to eql('(c_blocked IN (:p1))')
        expect(g1.params).to include(p1: [ 40, 50 ])
      end

      it 'should use the custom generator if provided' do
        g1 = Fl::Core::Query::Filter.new(cfg_2)

        clause = g1.generate({
                               blocked: {
                                 only: [ 2 ]
                               }
                             })
        expect(clause).to eql('(c_blocked = :p1)')
        expect(g1.params).to include(p1: 20)

        g1.reset
        clause = g1.generate({
                               blocked: {
                                 only: [ 2, 3 ]
                               }
                             })
        expect(clause).to eql('(c_blocked IN (:p1))')
        expect(g1.params).to include(p1: [ 20, 30 ])

        g1.reset
        clause = g1.generate({
                               blocked: {
                                 except: [ 3 ]
                               }
                             })
        expect(clause).to eql('(c_blocked != :p1)')
        expect(g1.params).to include(p1: 30)

        g1.reset
        clause = g1.generate({
                               blocked: {
                                 except: [ ]
                               }
                             })
        expect(clause).to eql('(c_blocked NOT IN (:p1))')
        expect(g1.params).to include(p1: [ ])

        g1.reset
        clause = g1.generate({
                               blocked: {
                                 only: [ 2, 3, 4, 5 ],
                                 except: [ 2, 3, 4, 6 ]
                               }
                             })
        expect(clause).to eql('(c_blocked = :p1)')
        expect(g1.params).to include(p1: 50)
      end
    end

    context ':timestamp' do
      it 'should handle all supported comparisons' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        t_1 = "2021-04-07 13:44:59 -0700"
        ts_1 = Time.parse(t_1)
        t_2 = "2021-04-07 14:44:59 -0700"
        ts_2 = Time.parse(t_2)

        clause = g1.generate({ ts1: { at: t_1 } })
        expect(clause).to eql('(c_ts1 = :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { not_at: t_1 } })
        expect(clause).to eql('(c_ts1 != :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { after: t_1 } })
        expect(clause).to eql('(c_ts1 > :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { at_or_after: t_1 } })
        expect(clause).to eql('(c_ts1 >= :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { before: t_1 } })
        expect(clause).to eql('(c_ts1 < :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { at_or_before: t_1 } })
        expect(clause).to eql('(c_ts1 <= :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { between: [ t_1, t_2 ] } })
        expect(clause).to eql('(c_ts1 BETWEEN :p1 AND :p2)')
        expect(g1.params).to include(p1: ts_1)
        expect(g1.params).to include(p2: ts_2)

        g1.reset
        clause = g1.generate({ ts1: { not_between: [ t_1, t_2 ] } })
        expect(clause).to eql('(c_ts1 NOT BETWEEN :p1 AND :p2)')
        expect(g1.params).to include(p1: ts_1)
        expect(g1.params).to include(p2: ts_2)
      end

      it 'should reorder timestamps as needed for :between and :not_between' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        t_1 = "2021-04-07 13:44:59 -0700"
        ts_1 = Time.parse(t_1)
        t_2 = "2021-04-07 14:44:59 -0700"
        ts_2 = Time.parse(t_2)

        g1.reset
        clause = g1.generate({ ts1: { between: [ t_2, t_1 ] } })
        expect(clause).to eql('(c_ts1 BETWEEN :p1 AND :p2)')
        expect(g1.params).to include(p1: ts_1)
        expect(g1.params).to include(p2: ts_2)

        g1.reset
        clause = g1.generate({ ts1: { not_between: [ t_2, t_1 ] } })
        expect(clause).to eql('(c_ts1 NOT BETWEEN :p1 AND :p2)')
        expect(g1.params).to include(p1: ts_1)
        expect(g1.params).to include(p2: ts_2)
      end

      it 'should return nil on an unknown comparison' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        t1 = "2021-04-07 13:44:59 -0700"
        ts = Time.parse(t1)
        clause = g1.generate({ ts1: { unknown: t1 } })
        expect(clause).to be_nil
      end

      it 'should raise with :between and :not_between if the value is not a two-element array' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        t1 = "2021-04-07 13:44:59 -0700"
        ts = Time.parse(t1)

        expect do
          clause = g1.generate({ ts1: { between: t1 } })
        end.to raise_exception(Fl::Core::Query::Filter::Exception)

        expect do
          clause = g1.generate({ ts1: { between: [ t1 ] } })
        end.to raise_exception(Fl::Core::Query::Filter::Exception)

        expect do
          clause = g1.generate({ ts1: { not_between: t1 } })
        end.to raise_exception(Fl::Core::Query::Filter::Exception)

        expect do
          clause = g1.generate({ ts1: { not_between: [ t1 ] } })
        end.to raise_exception(Fl::Core::Query::Filter::Exception)
      end
      
      it 'should handle all supported comparisons' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        t_1 = "2021-04-07 13:44:59 -0700"
        ts_1 = Time.parse(t_1)
        t_2 = "2021-04-07 14:44:59 -0700"
        ts_2 = Time.parse(t_2)

        clause = g1.generate({ ts1: { at: t_1 } })
        expect(clause).to eql('(c_ts1 = :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { not_at: t_1 } })
        expect(clause).to eql('(c_ts1 != :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { after: t_1 } })
        expect(clause).to eql('(c_ts1 > :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { at_or_after: t_1 } })
        expect(clause).to eql('(c_ts1 >= :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { before: t_1 } })
        expect(clause).to eql('(c_ts1 < :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { at_or_before: t_1 } })
        expect(clause).to eql('(c_ts1 <= :p1)')
        expect(g1.params).to include(p1: ts_1)

        g1.reset
        clause = g1.generate({ ts1: { between: [ t_1, t_2 ] } })
        expect(clause).to eql('(c_ts1 BETWEEN :p1 AND :p2)')
        expect(g1.params).to include(p1: ts_1)
        expect(g1.params).to include(p2: ts_2)

        g1.reset
        clause = g1.generate({ ts1: { not_between: [ t_1, t_2 ] } })
        expect(clause).to eql('(c_ts1 NOT BETWEEN :p1 AND :p2)')
        expect(g1.params).to include(p1: ts_1)
        expect(g1.params).to include(p2: ts_2)
      end

      it 'should use the custom generator if provided' do
        g1 = Fl::Core::Query::Filter.new(cfg_2)

        t_1 = "2021-04-07 13:44:59 -0700"
        ts_1 = Time.parse(t_1)

        clause = g1.generate({
                               ts1: { special: t_1 }
                             })
        expect(clause).to eql('(c_ts1 LIKE :p1)')
        expect(g1.params).to include(p1: ts_1.to_s)

        g1.reset
        clause = g1.generate({
                               ts1: { at: t_1 }
                             })
        expect(clause).to eql('(c_ts1 = :p1)')
        expect(g1.params).to include(p1: ts_1)
      end
    end

    context ':custom' do
      it 'should generate the WHERE clause as expected' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({ cstm: { foo: 'Abcd' } })
        expect(clause).to eql('(LOWER(c_custom) = :p1)')
        expect(g1.params).to include(p1: 'abcd')
      end

      it 'should raise an exception on a missing value' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        expect do
          clause = g1.generate({ cstm: { bar: 'Abcd' } })
        end.to raise_exception(Fl::Core::Query::Filter::Exception)
      end

      it 'should return an empty value if the custom bloc resolves to nil' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        clause = g1.generate({ nil_custom: { bar: 'Abcd' } })
        expect(clause).to be_nil
      end

      it 'should not be pushed to the clause array if the custom bloc resolves to nil' do
        g1 = Fl::Core::Query::Filter.new(cfg_1)

        t_1 = "2021-04-07 13:44:59 -0700"
        ts_1 = Time.parse(t_1)

        clause = g1.generate({
                               all: {
                                 ts1: { at: t_1 },
                                 nil_custom: { bar: 'Abcd' },
                                 ones: {
                                   only: [ 1, 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumOne/3' ]
                                 }
                               }
                             })
        expect(clause).to eql('((c_ts1 = :p1) AND (c_one IN (:p2)))')
        expect(g1.params).to include(p1: ts_1, p2: [ 1, 2, 3 ])

        g1.reset
        clause = g1.generate({
                               all: {
                                 nil_custom: { bar: 'Abcd' },
                                 ones: {
                                   only: [ 1, 'Fl::Core::TestDatumOne/2', 'gid://flcore/Fl::Core::TestDatumOne/3' ]
                                 }
                               }
                             })
        expect(clause).to eql('(c_one IN (:p1))')
        expect(g1.params).to include(p1: [ 1, 2, 3 ])

        g1.reset
        clause = g1.generate({
                               all: {
                                 ts1: { at: t_1 },
                                 nil_custom: { bar: 'Abcd' }
                               }
                             })
        expect(clause).to eql('(c_ts1 = :p1)')
        expect(g1.params).to include(p1: ts_1)
      end
    end
  end
end

#      print("++++++++++ #{clause} - #{g1.params}\n")
#      print("++++++++++ #{of} -> #{nf}\n")
