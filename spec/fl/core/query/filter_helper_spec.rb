RSpec.describe Fl::Core::Query::FilterHelper do
  let(:fh) { Fl::Core::Query::FilterHelper }

  let(:td1) { Fl::Core::TestDatumOne }
  let(:td2) { Fl::Core::TestDatumTwo }

  let(:ta1) { Fl::Core::TestActor.create(name: 'ta1') }
  
  let(:td1_1) { td1.create(owner: ta1, title: 'td1_1 title', content: 'td1_1 content') }
  let(:td1_2) { td1.create(owner: ta1, title: 'td1_2 title', content: 'td1_2 content') }
  let(:td1_3) { td1.create(owner: ta1, title: 'td1_3 title', content: 'td1_3 content') }
  let(:td1_4) { td1.create(owner: ta1, title: 'td1_4 title', content: 'td1_4 content') }
  let(:td1_5) { td1.create(owner: ta1, title: 'td1_5 title', content: 'td1_5 content') }
  let(:td1_6) { td1.create(owner: ta1, title: 'td1_6 title', content: 'td1_6 content') }

  let(:td2_1) { td1.create(owner: ta1, title: 'td2_1 title', content: 'td2_1 content') }
  let(:td2_2) { td1.create(owner: ta1, title: 'td2_2 title', content: 'td2_2 content') }
  let(:td2_3) { td1.create(owner: ta1, title: 'td2_3 title', content: 'td2_3 content') }
  let(:td2_4) { td1.create(owner: ta1, title: 'td2_4 title', content: 'td2_4 content') }
  let(:td2_5) { td1.create(owner: ta1, title: 'td2_5 title', content: 'td2_5 content') }
  let(:td2_6) { td1.create(owner: ta1, title: 'td2_6 title', content: 'td2_6 content') }
  
  describe '.boolean_query_flag' do
    it 'should accept Boolean values' do
      expect(fh.boolean_query_flag(true)).to eql(true)
      expect(fh.boolean_query_flag(false)).to eql(false)
    end

    it 'should accept numeric values' do
      expect(fh.boolean_query_flag(1)).to eql(true)
      expect(fh.boolean_query_flag(10)).to eql(true)
      expect(fh.boolean_query_flag(10.2)).to eql(true)

      expect(fh.boolean_query_flag(0)).to eql(false)
      expect(fh.boolean_query_flag(0.0)).to eql(false)
    end

    it 'should accept string values' do
      expect(fh.boolean_query_flag('1')).to eql(true)
      expect(fh.boolean_query_flag('10')).to eql(true)
      expect(fh.boolean_query_flag('0')).to eql(false)

      expect(fh.boolean_query_flag('true')).to eql(true)
      expect(fh.boolean_query_flag('TRUE')).to eql(true)
      expect(fh.boolean_query_flag('t')).to eql(true)
      expect(fh.boolean_query_flag('T')).to eql(true)
      expect(fh.boolean_query_flag('false')).to eql(false)
      expect(fh.boolean_query_flag('FALSE')).to eql(false)
      expect(fh.boolean_query_flag('f')).to eql(false)
      expect(fh.boolean_query_flag('F')).to eql(false)

      expect(fh.boolean_query_flag('yes')).to eql(true)
      expect(fh.boolean_query_flag('YES')).to eql(true)
      expect(fh.boolean_query_flag('y')).to eql(true)
      expect(fh.boolean_query_flag('Y')).to eql(true)
      expect(fh.boolean_query_flag('no')).to eql(false)
      expect(fh.boolean_query_flag('NO')).to eql(false)
      expect(fh.boolean_query_flag('n')).to eql(false)
      expect(fh.boolean_query_flag('N')).to eql(false)
    end

    it 'should accept nil values' do
      expect(fh.boolean_query_flag(nil)).to eql(false)
    end

    it 'should return false on any other types' do
      expect(fh.boolean_query_flag('not a value')).to eql(false)
      expect(fh.boolean_query_flag([ ])).to eql(false)
      expect(fh.boolean_query_flag({ })).to eql(false)
    end
  end

  describe '.check_object_class_and_id' do
    it 'should accept a class name' do
      expect(fh.check_object_class_and_id(td1.name, 10, nil)).to eql(10)

      expect(fh.check_object_class_and_id('Not::A::Class', 10, nil)).to eql(10)
    end

    it 'should accept a class' do
      expect(fh.check_object_class_and_id(td1, 10, nil)).to eql(10)
    end

    it 'should return nil with a nil class or id' do
      expect(fh.check_object_class_and_id(nil, 10, nil)).to be_nil
      expect(fh.check_object_class_and_id(td1, nil, nil)).to be_nil
    end

    it 'should check the class' do
      expect(fh.check_object_class_and_id(td1.name, 10, td1)).to eql(10)
      expect(fh.check_object_class_and_id(td1, 10, td1)).to eql(10)
      expect(fh.check_object_class_and_id(td1.name, 10, td1.name)).to eql(10)
      expect(fh.check_object_class_and_id(td1, 10, td1.name)).to eql(10)

      expect(fh.check_object_class_and_id(td1.name, 10, td2)).to be_nil
      expect(fh.check_object_class_and_id(td1, 10, td2)).to be_nil
      expect(fh.check_object_class_and_id(td1.name, 10, td2.name)).to be_nil
      expect(fh.check_object_class_and_id(td1, 10, td2.name)).to be_nil

      expect(fh.check_object_class_and_id('Not::A::Class', 10, td2)).to be_nil
      expect(fh.check_object_class_and_id('Not::A::Class', 10, td2)).to be_nil
      expect(fh.check_object_class_and_id(td1.name, 10, 'Not::A::Class')).to be_nil
      expect(fh.check_object_class_and_id(td1, 10, 'Not::A::Class')).to be_nil
    end
  end

  describe '.extract_identifier_from_reference' do
    it 'should accept an object that responds to :id' do
      expect(fh.extract_identifier_from_reference(td1_1)).to eql(td1_1.id)
    end
    
    it 'should accept an integer value' do
      expect(fh.extract_identifier_from_reference(10)).to eql(10)
    end

    it 'should accept a string of integers' do
      expect(fh.extract_identifier_from_reference('10')).to eql(10)
      expect(fh.extract_identifier_from_reference('10', td2)).to eql(10)
    end

    it 'should accept a SignedGlobalID' do
      sgid = td1_1.to_signed_global_id
      expect(fh.extract_identifier_from_reference(sgid)).to eql(td1_1.id)
    end

    it 'should accept a GlobalID' do
      gid = td1_1.to_global_id
      expect(fh.extract_identifier_from_reference(gid)).to eql(td1_1.id)
    end

    it 'should accept a string representation of a GlobalID' do
      gid = td1_1.to_global_id.to_s
      expect(fh.extract_identifier_from_reference(gid)).to eql(td1_1.id)
    end

    it 'should accept a string containing a fingerprint' do
      fp = td1_1.fingerprint
      expect(fh.extract_identifier_from_reference(fp)).to eql(td1_1.id)

      expect(fh.extract_identifier_from_reference('My::Class/10')).to eql(10)
    end

    it 'should accept a string representation of a SignedGlobalID' do
      sgid = td1_1.to_signed_global_id.to_s
      expect(fh.extract_identifier_from_reference(sgid)).to eql(td1_1.id)
    end

    it 'should return nil if all checks fail' do
      expect(fh.extract_identifier_from_reference('not_a_fingerprint')).to be_nil
      expect(fh.extract_identifier_from_reference({ })).to be_nil
      expect(fh.extract_identifier_from_reference([ ])).to be_nil
    end

    context 'with class check' do
      it 'should accept an object that responds to :id' do
        expect(fh.extract_identifier_from_reference(td1_1, td1)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(td1_1, td2)).to be_nil
      end
    
      it 'should accept an integer value' do
        expect(fh.extract_identifier_from_reference(10, td2)).to eql(10)
      end

      it 'should accept a string of integers' do
        expect(fh.extract_identifier_from_reference('10', td2)).to eql(10)
      end

      it 'should accept a SignedGlobalID' do
        sgid = td1_1.to_signed_global_id
        expect(fh.extract_identifier_from_reference(sgid, td1)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(sgid, td2)).to be_nil

        expect(fh.extract_identifier_from_reference(sgid, td1.name)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(sgid, td2.name)).to be_nil
      end

      it 'should accept a GlobalID' do
        gid = td1_1.to_global_id
        expect(fh.extract_identifier_from_reference(gid, td1)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(gid, td2)).to be_nil

        expect(fh.extract_identifier_from_reference(gid, td1.name)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(gid, td2.name)).to be_nil
      end

      it 'should accept a string representation of a GlobalID' do
        gid = td1_1.to_global_id.to_s
        expect(fh.extract_identifier_from_reference(gid, td1)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(gid, td2)).to be_nil

        expect(fh.extract_identifier_from_reference(gid, td1.name)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(gid, td2.name)).to be_nil
      end

      it 'should accept a string containing a fingerprint' do
        fp = td1_1.fingerprint
        expect(fh.extract_identifier_from_reference(fp, td1)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(fp, td2)).to be_nil

        expect(fh.extract_identifier_from_reference(fp, td1.name)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(fp, td2.name)).to be_nil

        expect(fh.extract_identifier_from_reference('My::Class/10', td1)).to be_nil
        expect(fh.extract_identifier_from_reference('My::Class/10', td1.name)).to be_nil
      end

      it 'should accept a string representation of a SignedGlobalID' do
        sgid = td1_1.to_signed_global_id.to_s
        expect(fh.extract_identifier_from_reference(sgid, td1)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(sgid, td2)).to be_nil

        expect(fh.extract_identifier_from_reference(sgid, td1.name)).to eql(td1_1.id)
        expect(fh.extract_identifier_from_reference(sgid, td2.name)).to be_nil
      end
    end
  end

  describe '.convert_list_of_references' do
    it 'should support all formats in extract_identifier_from_reference' do
      rl = [ 10, '20', td1_1.to_signed_global_id, td1_2.to_global_id, td1_3.to_global_id.to_s,
             td1_4.fingerprint, td1_5.to_signed_global_id.to_s, td1_6 ]
      xl = [ 10, 20, td1_1.id, td1_2.id, td1_3.id,
             td1_4.id, td1_5.id, td1_6.id ]

      expect(fh.convert_list_of_references(rl, td1)).to eql(xl)
      expect(fh.convert_list_of_references(rl, td1.name)).to eql(xl)
    end

    it 'should run class checks' do
      rl = [ 10, '20', td1_1.to_signed_global_id, td1_2.to_global_id, td1_3.to_global_id.to_s,
             td1_4.fingerprint, td1_5.to_signed_global_id.to_s, td1_6, 'no_fingerprint', [ ], { } ]
      xl = [ 10, 20 ]

      expect(fh.convert_list_of_references(rl, td2)).to eql(xl)
      expect(fh.convert_list_of_references(rl, td2.name)).to eql(xl)
    end
  end

  describe '.partition_lists_of_references' do
    it 'should support all formats supported by .convert_list_of_references' do
      rl = [ 10, '20', td1_1.to_signed_global_id, td1_2.to_global_id, td1_3.to_global_id.to_s,
             td1_4.fingerprint, td1_5.to_signed_global_id.to_s, td1_6, 10.4, '10.8', 'not_a_fingerprint', [ ], { } ]
      xl = [ 10, 20, td1_1.id, td1_2.id, td1_3.id,
             td1_4.id, td1_5.id, td1_6.id ]

      h = fh.partition_lists_of_references({ only: rl }, td1)
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(xl)

      h = fh.partition_lists_of_references({ only: rl }, td1.name)
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(xl)

      h = fh.partition_lists_of_references({ except: rl }, td1)
      expect(h).to be_a(Hash)
      expect(h).to include(:except)
      expect(h[:except]).to eql(xl)

      h = fh.partition_lists_of_references({ except: rl }, td1.name)
      expect(h).to be_a(Hash)
      expect(h).to include(:except)
      expect(h[:except]).to eql(xl)
    end
    
    it 'should filter by class' do
      rl = [ 10, '20', td1_1.to_signed_global_id, td1_2.to_global_id, td1_3.to_global_id.to_s,
             td1_4.fingerprint, td1_5.to_signed_global_id.to_s, td1_6, 10.4, '10.8', 'not_a_fingerprint', [ ], { } ]
      xl = [ 10, 20 ]

      h = fh.partition_lists_of_references({ only: rl }, td2)
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(xl)

      h = fh.partition_lists_of_references({ only: rl }, td2.name)
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(xl)

      h = fh.partition_lists_of_references({ except: rl }, td2)
      expect(h).to be_a(Hash)
      expect(h).to include(:except)
      expect(h[:except]).to eql(xl)

      h = fh.partition_lists_of_references({ except: rl }, td2.name)
      expect(h).to be_a(Hash)
      expect(h).to include(:except)
      expect(h[:except]).to eql(xl)
    end

    it 'should adjust :only and :except lists' do
      ol = [ 10, '20', td1_1.to_signed_global_id, td1_2.to_global_id, td1_3.to_global_id.to_s,
             td1_4.fingerprint, td1_5.to_signed_global_id.to_s, td1_6 ]
      el = [ 10, td1_1.to_signed_global_id, td1_2.to_global_id,
             td1_4.fingerprint, 10.4, '10.8', 'not_a_fingerprint', [ ], { } ]
      oxl = [ 20, td1_3.id, td1_5.id, td1_6.id ]

      h = fh.partition_lists_of_references({ only: ol, except: el }, td1)
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(oxl)

      h = fh.partition_lists_of_references({ only: ol, except: el }, td1.name)
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(oxl)
    end
  end

  describe '.extract_fingerprint_from_reference' do
    it 'should accept an object that responds to :fingerprint' do
      expect(fh.extract_fingerprint_from_reference(td1_1)).to eql(td1_1.fingerprint)
    end
    
    it 'should accept a SignedGlobalID' do
      sgid = td1_1.to_signed_global_id
      expect(fh.extract_fingerprint_from_reference(sgid)).to eql(td1_1.fingerprint)
    end

    it 'should accept a GlobalID' do
      gid = td1_1.to_global_id
      expect(fh.extract_fingerprint_from_reference(gid)).to eql(td1_1.fingerprint)
    end

    it 'should accept a string representation of a GlobalID' do
      gid = td1_1.to_global_id.to_s
      expect(fh.extract_fingerprint_from_reference(gid)).to eql(td1_1.fingerprint)
    end

    it 'should accept a string containing a fingerprint' do
      fp = td1_1.fingerprint
      expect(fh.extract_fingerprint_from_reference(fp)).to eql(td1_1.fingerprint)

      expect(fh.extract_fingerprint_from_reference('My::Class/10')).to eql('My::Class/10')
    end

    it 'should accept a string representation of a SignedGlobalID' do
      sgid = td1_1.to_signed_global_id.to_s
      expect(fh.extract_fingerprint_from_reference(sgid)).to eql(td1_1.fingerprint)
    end

    it 'should return nil if all checks fail' do
      expect(fh.extract_fingerprint_from_reference('not_a_fingerprint')).to be_nil
      expect(fh.extract_fingerprint_from_reference({ })).to be_nil
      expect(fh.extract_fingerprint_from_reference([ ])).to be_nil
    end
  end

  describe '.convert_list_of_polymorphic_references' do
    it 'should support all formats in extract_fingerprint_from_reference' do
      rl = [ td1_1.to_signed_global_id, td2_2.to_global_id, td1_3.to_global_id.to_s, td2_4.fingerprint,
             td1_5.to_signed_global_id.to_s, 'My::Class/30', td2_6,
             'not_a_fingerprint', { }, [ ] ]
      xl = [ td1_1.fingerprint, td2_2.fingerprint, td1_3.fingerprint, td2_4.fingerprint,
             td1_5.fingerprint, 'My::Class/30', td2_6.fingerprint ]

      expect(fh.convert_list_of_polymorphic_references(rl)).to eql(xl)
    end
  end

  describe '.partition_lists_of_polymorphic_references' do
    it 'should support all formats supported by .convert_list_of_polymorphic_references' do
      rl = [ 10, '20', td1_1.to_signed_global_id, td2_2.to_global_id, td1_3.to_global_id.to_s,
             td2_4.fingerprint, td1_5.to_signed_global_id.to_s, td2_6, 'My::Class/30',
             10.4, '10.8', 'not_a_fingerprint', [ ], { } ]
      xl = [ td1_1.fingerprint, td2_2.fingerprint, td1_3.fingerprint,
             td2_4.fingerprint, td1_5.fingerprint, td2_6.fingerprint, 'My::Class/30' ]

      h = fh.partition_lists_of_polymorphic_references({ only: rl })
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(xl)

      h = fh.partition_lists_of_polymorphic_references({ except: rl })
      expect(h).to be_a(Hash)
      expect(h).to include(:except)
      expect(h[:except]).to eql(xl)
    end
    
    it 'should adjust :only and :except lists' do
      ol = [ 10, '20', td1_1.to_signed_global_id, td2_2.to_global_id, td1_3.to_global_id.to_s,
             td2_4.fingerprint, td1_5.to_signed_global_id.to_s, td2_6, 'My::Class/30' ]
      el = [ 10, td1_1.to_signed_global_id, td2_2.to_global_id,
             td2_4.fingerprint, 10.4, '10.8', 'not_a_fingerprint', [ ], { } ]
      oxl = [ td1_3.fingerprint, td1_5.fingerprint, td2_6.fingerprint, 'My::Class/30' ]

      h = fh.partition_lists_of_polymorphic_references({ only: ol, except: el })
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(oxl)
    end
  end

  describe '.partition_filter_lists' do
    it 'should trigger the block to process lists' do
      rl = [ 10, '20', td1_1.to_signed_global_id, td1_2.to_global_id, td1_3.to_global_id.to_s,
             td1_4.fingerprint, td1_5.to_signed_global_id.to_s, 10.4, '10.8', 'not_a_fingerprint', [ ], { } ]
      xl = [ 10, td1_1.id, td1_3.id, td1_5.id ]

      did_see = [ ]
      h = fh.partition_filter_lists({ only: rl }) do |l, type|
        did_see.push(type)
        rv = [ ]
        fh.convert_list_of_references(l, nil).each_with_index { |e, idx| rv.push(e) if (idx % 2) == 0 }
        rv
      end
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(xl)
      expect(did_see).to eql([ :only ])

      did_see = [ ]
      h = fh.partition_filter_lists({ except: rl }) do |l, type|
        did_see.push(type)
        rv = [ ]
        fh.convert_list_of_references(l, nil).each_with_index { |e, idx| rv.push(e) if (idx % 2) == 0 }
        rv
      end
      expect(h).to be_a(Hash)
      expect(h).to include(:except)
      expect(h[:except]).to eql(xl)
      expect(did_see).to eql([ :except ])
    end

    it 'should adjust :only and :except lists' do
      ol = [ 10, '20', td1_1.to_signed_global_id, td1_2.to_global_id, td1_3.to_global_id.to_s,
             td1_4.fingerprint, td1_5.to_signed_global_id.to_s, 10.4, '10.8', 'not_a_fingerprint', [ ], { } ]
      el = [ 10, td1_4.id, td1_5.id ]
      xl = [ td1_1.id, td1_3.id ]

      did_see = [ ]
      h = fh.partition_filter_lists({ only: ol, except: el }) do |l, type|
        did_see.push(type)

        if type == :only
          rv = [ ]
          fh.convert_list_of_references(l, nil).each_with_index { |e, idx| rv.push(e) if (idx % 2) == 0 }
          rv
        else
          fh.convert_list_of_references(l, nil)
        end
      end
      expect(h).to be_a(Hash)
      expect(h).to include(:only)
      expect(h[:only]).to eql(xl)
      expect(did_see).to eql([ :only, :except ])
    end
  end
end
