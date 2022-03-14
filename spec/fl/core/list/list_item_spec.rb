require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

if defined?(MyListItemOne).nil?
  class MyListItemOne < Fl::Core::List::BaseItem
  end
end
  
if defined?(MyListOne).nil?
  class MyListOne < Fl::Core::List::List
    protected
  
    def instantiate_list_item(attrs)
      return MyListItemOne.new(attrs)
    end
  end
end
  
Fl::Core::List::Helper.make_listable(Fl::Core::TestDatumOne)
Fl::Core::List::Helper.make_listable(Fl::Core::TestDatumTwo)
# Fl::Core::List::Helper.make_listable(Fl::Core::TestDatumThree)

RSpec.describe Fl::Core::List::Item, type: :model do
  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }

  let(:d10) { create(:test_datum_one, owner: a1, content: '10') }
  let(:d11) { create(:test_datum_one, owner: a2, content: '11') }
  let(:d12) { create(:test_datum_one, owner: a2, content: '12') }
  let(:d20) { create(:test_datum_two, owner: a2, content: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a2, content: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, content: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a1, content: '30') }

  let(:l1) { create(:list, owner: a1) }
  let(:l2) { create(:list, owner: a1) }

  describe '#initialize' do
    it 'should fail with empty attributes' do
      li1 = Fl::Core::List::Item.new
      expect(li1.valid?).to eq(false)
      expect(li1.errors.messages.keys).to contain_exactly(:list, :listed_object)
    end

    it 'should succeed with list and listable' do
      l = create(:list)
      li1 = Fl::Core::List::Item.new(list: l, listed_object: d11)
      expect(li1.valid?).to eq(true)
      expect(li1.owner).to be_nil
      expect(li1.list.fingerprint).to eql(l.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
    end

    it 'should accept an owner attribute' do
      li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a2)
      expect(li1.valid?).to eq(true)
      expect(li1.owner.id).to eql(a2.id)
    end

    it 'should accept a name attribute' do
      li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, name: 'item1')
      expect(li1.valid?).to eq(true)
      expect(li1.name).to eql('item1')
    end

    it 'should use the list owner if necessary' do
      l = create(:list)
      li1 = Fl::Core::List::Item.new(list: l, listed_object: d11)
      expect(li1.valid?).to eq(true)
      expect(li1.owner).to be_nil

      l2 = create(:list, owner: a1)
      li2 = Fl::Core::List::Item.new(list: l2, listed_object: d11)
      expect(li2.valid?).to eq(true)
      expect(li2.owner.id).to eql(a1.id)
    end

    it 'should accept fingerprint arguments' do
      l = create(:list)
      li1 = Fl::Core::List::Item.new(list: l.fingerprint, listed_object: d11.fingerprint,
                                              owner: a2.fingerprint, state_updated_by: a1.fingerprint)
      expect(li1.valid?).to eq(true)
      expect(li1.owner.fingerprint).to eql(a2.fingerprint)
      expect(li1.list.fingerprint).to eql(l.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
    end

    it 'should use the default lock state if :state_locked is not present' do
      expect(l2.update(default_item_state_locked: false)).to eql(true)
      
      li1 = Fl::Core::List::Item.new(list: l2, listed_object: d11, owner: a2)
      expect(li1.valid?).to eq(true)
      expect(li1.state_locked).to eql(false)
      
      li2 = Fl::Core::List::Item.new(list: l2, listed_object: d12, owner: a2, state_locked: true)
      expect(li2.valid?).to eq(true)
      expect(li2.state_locked).to eql(true)
    end
  end

  describe 'creation' do
    it 'should set the fingerprint attributes' do
      li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a2, name: 'item1')
      expect(li1.valid?).to eq(true)
      expect(li1.owner_fingerprint).to be_nil
      expect(li1.listed_object_fingerprint).to be_nil
      
      expect(li1.save).to eq(true)
      expect(li1.owner.id).to eql(a2.id)
      expect(li1.valid?).to eq(true)
      expect(li1.name).to eql('item1')
      expect(li1.owner_fingerprint).to eql(li1.owner.fingerprint)
      expect(li1.listed_object_fingerprint).to eql(li1.listed_object.fingerprint)
    end
  end
  
  describe 'validation' do
    it 'should fail if :listed_object is not a listable' do
      d3 = create(:test_datum_three, owner: a1)
      li1 = Fl::Core::List::Item.new(list: l1, listed_object: d3)
      expect(li1.valid?).to eq(false)
      expect(li1.errors.messages.keys).to contain_exactly(:listed_object)
    end

    context '#name' do
      it 'should accept punctuation in name' do
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d21, name: 'l1 - d21')
        expect(li1.valid?).to eq(true)

        li2 = Fl::Core::List::Item.new(list: l1, listed_object: d22, name: 'l1 - d22 .+;:')
        expect(li2.valid?).to eq(true)
      end
      
      it 'should fail if name contains / or \\' do
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d21, name: 'l1/d21')
        expect(li1.valid?).to eq(false)
        expect(li1.errors.messages.keys).to contain_exactly(:name)

        li2 = Fl::Core::List::Item.new(list: l1, listed_object: d22, name: 'l1\\d22')
        expect(li2.valid?).to eq(false)
        expect(li2.errors.messages.keys).to contain_exactly(:name)
      end
      
      it 'should fail if name is longer than 200 characters' do
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d21,
                                                name: '0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 ')
        expect(li1.valid?).to eq(false)
        expect(li1.errors.messages.keys).to contain_exactly(:name)
      end
      
      it 'should fail on duplicate names on the same list' do
        li1 = Fl::Core::List::Item.create(list: l1, listed_object: d21, name: 'item1')
        expect(li1.valid?).to eq(true)

        li2 = Fl::Core::List::Item.new(list: l1, listed_object: d22, name: 'item1')
        expect(li2.valid?).to eq(false)
        expect(li2.errors.messages.keys).to contain_exactly(:name)

        li2.name = 'item2'
        expect(li2.save).to eq(true)
        li2.name = 'item1'
        expect(li2.valid?).to eq(false)
      end
      
      it 'should accept duplicate names on different lists' do
        li1 = Fl::Core::List::Item.create(list: l1, listed_object: d21, name: 'item1')
        expect(li1.valid?).to eq(true)

        li2 = Fl::Core::List::Item.new(list: l2, listed_object: d22, name: 'item1')
        expect(li2.valid?).to eq(true)
      end
    end
  end
  
  describe '#update' do
    it 'should ignore :list, :listed_object, and :owner attributes if persisted' do
      li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                              state: Fl::Core::List::Item::STATE_SELECTED)
      expect(li1.valid?).to eq(true)
      expect(li1.list.fingerprint).to eql(l1.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
      expect(li1.owner.fingerprint).to eql(a1.fingerprint)
      expect(li1.state).to eql(Fl::Core::List::Item::STATE_SELECTED)

      l2 = create(:list)
      expect(li1.update(list: l2, listed_object: d12, owner: a2,
                        state: Fl::Core::List::Item::STATE_DESELECTED)).to eql(true)
      expect(li1.valid?).to eq(true)
      expect(li1.list.fingerprint).to eql(l2.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d12.fingerprint)
      expect(li1.owner.fingerprint).to eql(a2.fingerprint)
      expect(li1.state).to eql(Fl::Core::List::Item::STATE_DESELECTED)

      expect(li1.save).to eql(true)
      expect(li1.update(list: l1, listed_object: d11, owner: a1,
                        state: Fl::Core::List::Item::STATE_SELECTED)).to eql(true)
      expect(li1.valid?).to eq(true)
      expect(li1.list.fingerprint).to eql(l2.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d12.fingerprint)
      expect(li1.owner.fingerprint).to eql(a2.fingerprint)
      expect(li1.state).to eql(Fl::Core::List::Item::STATE_SELECTED)
    end
  end

  describe '#list=' do
    it 'should not overwrite :list for a persisted object' do
      li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                              state: Fl::Core::List::Item::STATE_SELECTED)

      l2 = create(:list)
      li1.list = l2
      expect(li1.list.fingerprint).to eql(l2.fingerprint)
      expect(li1.save).to eql(true)
      li1.list = l1
      expect(li1.list.fingerprint).to eql(l2.fingerprint)
    end
  end

  describe '#listed_object=' do
    it 'should not overwrite :listed_object for a persisted object' do
      li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                              state: Fl::Core::List::Item::STATE_SELECTED)

      li1.listed_object = d12
      expect(li1.listed_object.fingerprint).to eql(d12.fingerprint)
      expect(li1.save).to eql(true)
      li1.listed_object = d11
      expect(li1.listed_object.fingerprint).to eql(d12.fingerprint)
    end
  end
  
  describe 'state management' do
    context '#set_state' do
      it 'should store the actor' do
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                       state: Fl::Core::List::Item::STATE_SELECTED)
        expect(li1.state).to eql(Fl::Core::List::Item::STATE_SELECTED)
        expect(li1.state_updated_by).to be_an_instance_of(a1.class)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)

        li1.set_state(Fl::Core::List::Item::STATE_DESELECTED, a2)
        expect(li1.state).to eql(Fl::Core::List::Item::STATE_DESELECTED)
        expect(li1.state_updated_by).to be_an_instance_of(a2.class)
        expect(li1.state_updated_by.fingerprint).to eql(a2.fingerprint)
      end

      it 'should use the item\'s owner if necessary' do
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                       state: Fl::Core::List::Item::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)

        li1.set_state(Fl::Core::List::Item::STATE_DESELECTED, a2)
        expect(li1.state).to eql(Fl::Core::List::Item::STATE_DESELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a2.fingerprint)

        li1.set_state(Fl::Core::List::Item::STATE_SELECTED)
        expect(li1.state).to eql(Fl::Core::List::Item::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)
      end
    end

    context '#state=' do
      it 'should use the item\'s owner' do
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                       state: Fl::Core::List::Item::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)

        li1.set_state(Fl::Core::List::Item::STATE_DESELECTED, a2)
        expect(li1.state).to eql(Fl::Core::List::Item::STATE_DESELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a2.fingerprint)

        li1.state = Fl::Core::List::Item::STATE_SELECTED
        expect(li1.state).to eql(Fl::Core::List::Item::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)
      end
    end

    context '#state_note=' do
      it 'should update the note' do
        n1 = 'state note 1'
        n2 = 'state note 2'
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                       state: Fl::Core::List::Item::STATE_SELECTED,
                                       state_note: n1)
        expect(li1.state_note).to eql(n1)
        li1.state_note = n2
        expect(li1.state_note).to eql(n2)
      end

      it 'should sanitize the note' do
        li1 = Fl::Core::List::Item.new(list: l1, listed_object: d11, owner: a1,
                                       state: Fl::Core::List::Item::STATE_SELECTED)

        # we only check for simple sanitizing, under the assumption that if it works for this it also
        # works for all others (the attribute filters are tested separately)
        
        html = '<p>Script: <script type="text/javascript">script contents</script> here</p>'
        nhtm = '<p>Script:  here</p>'
        li1.state_note = html
        expect(li1.state_note).to eql(nhtm)
      end
    end
  end

  describe 'model hash support' do
    let(:id_keys) { [ :type, :api_root, :fingerprint, :id, :global_id ] }
    let(:min_keys) { [ :owner, :list, :listed_object, :state_locked, :state, :sort_order, :item_summary, :name ] }
    let(:std_keys) { [ :state_updated_at, :state_updated_by, :state_note ] }

    context '#to_hash' do
      it 'should track :verbosity' do
        li1 = Fl::Core::List::Item.create(list: l1, listed_object: d11, owner: a1,
                                          state: Fl::Core::List::Item::STATE_SELECTED)

        h = li1.to_hash(a1, { verbosity: :id })
        expect(h.keys).to match_array(id_keys)

        ignore_keys = id_keys | [ ]
        h = li1.to_hash(a1, { verbosity: :ignore })
        expect(h.keys).to match_array(ignore_keys)

        minimal_keys = id_keys | [ :created_at, :updated_at ] | min_keys
        h = li1.to_hash(a1, { verbosity: :minimal })
        expect(h.keys).to match_array(minimal_keys)

        standard_keys = minimal_keys | std_keys
        h = li1.to_hash(a1, { verbosity: :standard })
        expect(h.keys).to match_array(standard_keys)

        verbose_keys = standard_keys | [ ]
        h = li1.to_hash(a1, { verbosity: :verbose })
        expect(h.keys).to match_array(verbose_keys)

        complete_keys = verbose_keys | [ ]
        h = li1.to_hash(a1, { verbosity: :complete })
        expect(h.keys).to match_array(complete_keys)
      end

      it 'should customize key lists' do
        li1 = Fl::Core::List::Item.create(list: l1, listed_object: d11, owner: a1,
                                          state: Fl::Core::List::Item::STATE_SELECTED)

        h_keys = id_keys | [ :list ]
        h = li1.to_hash(a1, { verbosity: :id, include: [ :list ] })
        expect(h.keys).to match_array(h_keys)

        minimal_keys = id_keys | [ :created_at, :updated_at ] | min_keys
        h_keys = minimal_keys - [ :list, :sort_order ]
        h = li1.to_hash(a1, { verbosity: :minimal, except: [ :list, :sort_order ] })
        expect(h.keys).to match_array(h_keys)
      end

      it 'should customize key lists for subobjects' do
        li1 = Fl::Core::List::Item.create(list: l1, listed_object: d11, owner: a1,
                                          state: Fl::Core::List::Item::STATE_SELECTED)

        h = li1.to_hash(a1, { verbosity: :minimal })
        lo_keys = id_keys + [ :title, :content, :created_at, :updated_at, :permissions ]
        expect(h[:listed_object].keys).to match_array(lo_keys)

        h = li1.to_hash(a1, {
                          verbosity: :minimal,
                          to_hash: {
                            listed_object: { verbosity: :minimal },
                            owner: { verbosity: :id },
                            list: { verbosity: :id, include: :title }
                          }
                        })
        lo_keys = id_keys + [ :title, :content, :created_at, :updated_at, :permissions ]
        expect(h[:listed_object].keys).to match_array(lo_keys)
        l_keys = id_keys + [ :title ]
        expect(h[:list].keys).to match_array(l_keys)
        o_keys = id_keys + [ ]
        expect(h[:owner].keys).to match_array(o_keys)
      end
    end
  end

  describe '.build_query' do
    it 'should generate a simple query from default options' do
      l10 = create(:list, objects: [ d10, d20, d21, d11 ])
      l11 = create(:list, objects: [ d10, d22, d20, d12 ])
      
      q = Fl::Core::List::Item.build_query()
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11, d10, d22, d20, d12 ]))
    end

    it 'should process the :lists filter' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Core::List::Item.build_query(filters: { lists: { only: l10.fingerprint } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { lists: { only: [ l10.fingerprint ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { lists: { only: l10 } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { lists: { except: l11.fingerprint } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { lists: { except: [ l11.fingerprint ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { lists: { except: [ l10, l11.fingerprint ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))
    end

    it 'should process the :owners filter' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Core::List::Item.build_query(filters: { owners: { only: a1.fingerprint } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { owners: { only: [ a1.fingerprint ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { owners: { only: a1 } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { owners: { except: a2.fingerprint } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { owners: { except: [ a2.fingerprint ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { owners: { except: [ a1, a2.fingerprint ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))
    end

    it 'should process the :listables filter' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Core::List::Item.build_query(filters: { listables: { only: d10.fingerprint } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d10 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { listables: { only: [ d10.fingerprint, d12 ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d10, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { listables: { only: d10 } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d10 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { listables: { except: d22.fingerprint } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11, d10, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { listables: { except: [ d22.fingerprint, d10, d11 ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d20, d21, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: { listables: { except: [ d10, d11, d12, d20, d21, d22 ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))
    end

    it 'should filter by combination of list, owner, and listable' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             lists: { only: l10.fingerprint },
                                             owners: { only: a1 }
                                           })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d11 ]))
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             lists: { only: [ l11 ] },
                                             owners: { except: [ a1 ] }
                                          })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10 ]))
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             owners: { only: a1 },
                                             listables: { only: [ d10, d11, d21 ] }
                                           })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d11 ]))
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             owners: { only: a1 },
                                             listables: { except: [ d10 ] }
                                           })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d20, d11, d22, d20, d12 ]))
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             lists: { only: l10 },
                                             owners: { only: a1 },
                                             listables: { only: d20 }
                                           })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d20 ]))
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             lists: { only: l10 },
                                             owners: { only: a1 },
                                             listables: { only: d21 }
                                           })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))

      q = Fl::Core::List::Item.build_query(filters: {
                                             lists: { only: l10 },
                                             owners: { except: a1 },
                                             listables: { except: d21 }
                                           })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ ]))

      q = Fl::Core::List::Item.build_query(filters: {
                                             lists: { only: l10 },
                                             owners: { only: a1 },
                                             listables: { except: [ d10, d21 ] }
                                           })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d20, d11 ]))
    end

    it 'should process :order, :offset, :limit' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             lists: { only: l10.fingerprint },
                                             owners: { only: a1 }
                                           },
                                           offset: 1, limit: 1)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             owners: { only: a1 },
                                             listables: { except: [ d10 ] }
                                           },
                                           order: 'list_id ASC, sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d11, d20, d12, d20, d22 ]))
      
      q = Fl::Core::List::Item.build_query(filters: {
                                             owners: { only: a1 },
                                             listables: { except: [ d10 ] }
                                           },
                                           offset: 1, limit: 3,
                                           order: 'list_id ASC, sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20, d12, d20 ]))
    end
  end

  describe '.query_for_list' do
    it 'should restrict to the given list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Core::List::Item.query_for_list(l10)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10, d20, d21, d11 ]))

      q = Fl::Core::List::Item.query_for_list(l11, filters: { owners: { only: a1 } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d22, d20, d12 ]))
      
      q = Fl::Core::List::Item.query_for_list(l11, filters: { owners: { except: [ a1 ] } })
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to match_array(obj_fingerprints([ d10 ]))

      q = Fl::Core::List::Item.query_for_list(l10, filters: {
                                                owners: { only: a1 }
                                              },
                                              order: 'sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d11, d20, d10 ]))

      q = Fl::Core::List::Item.query_for_list(l10, filters: {
                                                owners: { only: a1 }
                                              },
                                              limit: 1, offset: 1,
                                              order: 'sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
    end
  end

  describe '.query_for_listable' do
    it 'should restrict to the given listable' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      l12 = create(:list, objects: [ [ d21, a2 ], [ d22, a1 ] ])
      l13 = create(:list, objects: [ [ d22, a2 ], [ d12, a2 ] ])

      # The default sort order is 'updated_at DESC'
      
      q = Fl::Core::List::Item.query_for_listable(d20)
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11, l10 ]))
      
      q = Fl::Core::List::Item.query_for_listable(d12)
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l13, l11 ]))
      
      q = Fl::Core::List::Item.query_for_listable(d12, order: 'list_id ASC')
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11, l13 ]))
    end
  end

  describe '.query_for_listable_in_list' do
    it 'should find a listable in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      q = Fl::Core::List::Item.query_for_listable_in_list(d20, l10)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l10 ]))

      q = Fl::Core::List::Item.query_for_listable_in_list(d22.fingerprint, l11)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11 ]))

      q = Fl::Core::List::Item.query_for_listable_in_list(d20, l10.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l10 ]))

      q = Fl::Core::List::Item.query_for_listable_in_list(d22.fingerprint, l11.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11 ]))
    end

    it 'should not find a listable not in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      q = Fl::Core::List::Item.query_for_listable_in_list(d11, l11)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Core::List::Item.query_for_listable_in_list(d11.fingerprint, l11)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Core::List::Item.query_for_listable_in_list(d11, l11.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Core::List::Item.query_for_listable_in_list(d11.fingerprint, l11.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))
    end
  end

  describe '.find_listable_in_list' do
    it 'should find a listable in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      l = Fl::Core::List::Item.find_listable_in_list(d20, l10)
      expect(l.fingerprint).to eql(d20.fingerprint)

      l = Fl::Core::List::Item.find_listable_in_list(d22.fingerprint, l11)
      expect(l.fingerprint).to eql(d22.fingerprint)

      l = Fl::Core::List::Item.find_listable_in_list(d20, l10.fingerprint)
      expect(l.fingerprint).to eql(d20.fingerprint)

      l = Fl::Core::List::Item.find_listable_in_list(d22.fingerprint, l11.fingerprint)
      expect(l.fingerprint).to eql(d22.fingerprint)
    end

    it 'should not find a listable not in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      l = Fl::Core::List::Item.find_listable_in_list(d11, l11)
      expect(l).to be_nil

      l = Fl::Core::List::Item.find_listable_in_list(d11.fingerprint, l11)
      expect(l).to be_nil

      l = Fl::Core::List::Item.find_listable_in_list(d11, l11.fingerprint)
      expect(l).to be_nil

      l = Fl::Core::List::Item.find_listable_in_list(d11.fingerprint, l11.fingerprint)
      expect(l).to be_nil
    end
  end

  describe '.refresh_item_summaries' do
    it 'should update all summaries' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      nt = 'new title for summary'
      d20.title = nt
      expect(d20.save).to eql(true)
      d20.reload
      expect(d20.title).to eql(nt)
      q = Fl::Core::List::Item.query_for_listable(d20)
      ql = q.map { |li| li.item_summary }
      expect(ql).to eql([ d20.title, nt ])
    end
  end

  describe '.resolve_object' do
    it 'should return a list item as is' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      li = l10.list_items.first
      o = Fl::Core::List::Item.resolve_object(li, l10, a2)
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(o.owner.fingerprint).to eql(a1.fingerprint)
    end

    it 'should process a fingerprint' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Core::List::Item.resolve_object(d22.fingerprint, l10, a2)
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end

    it 'should process a model instance' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Core::List::Item.resolve_object(d22, l10, a2)
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end

    it 'should process a hash' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Core::List::Item.resolve_object({ listed_object: d22 }, l10, a2)
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = Fl::Core::List::Item.resolve_object({ listed_object: d22.fingerprint }, l10, a2)
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end

    it 'should fail if a list item is not in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      li = l10.list_items.first
      o = Fl::Core::List::Item.resolve_object(li, l11, a2)
      expect(o).to be_an_instance_of(String)
    end

    it 'should fail if the resolved object is not listable' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Core::List::Item.resolve_object(d30, l10, a2)
      expect(o).to be_an_instance_of(String)

      o = Fl::Core::List::Item.resolve_object(d30.fingerprint, l10, a2)
      expect(o).to be_an_instance_of(String)

      o = Fl::Core::List::Item.resolve_object({ listed_object: d30.fingerprint }, l10, a2)
      expect(o).to be_an_instance_of(String)
    end

    context 'with a custom list class' do
      it 'should process a fingerprint' do
        l10 = MyListOne.create(objects: [ d10, d20, d21, d11 ], owner: a1)

        o = Fl::Core::List::Item.resolve_object(d22.fingerprint, l10, a2)
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)
      end

      it 'should process a model instance' do
        l10 = MyListOne.create(objects: [ d10, d20, d21, d11 ], owner: a1)

        o = Fl::Core::List::Item.resolve_object(d22, l10, a2)
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)
      end

      it 'should process a hash' do
        l10 = MyListOne.create(objects: [ d10, d20, d21, d11 ], owner: a1)

        o = Fl::Core::List::Item.resolve_object({ listed_object: d22 }, l10, a2)
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)

        o = Fl::Core::List::Item.resolve_object({ listed_object: d22.fingerprint }, l10, a2)
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)
      end
    end
  end

  describe '.normalize_objects' do
    it 'should resolve correctly' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      objects = [ l10.list_items.first,
                  d22.fingerprint, d22,
                  { listed_object: d22 }, { listed_object: d22.fingerprint },
                  l11.list_items.first,
                  d30, d30.fingerprint, { listed_object: d30 },
                  { listed_object: d21, owner: a3, name: 'd21' },
                  { listed_object: d12, owner: a2, name: 'd12' }
                ]
      errcount, resolved = Fl::Core::List::Item.normalize_objects(objects, l10, a2)
      expect(errcount).to eql(4)
      
      o = resolved[0]
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[1]
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[2]
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[3]
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[4]
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[5]
      expect(o).to be_an_instance_of(String)

      o = resolved[6]
      expect(o).to be_an_instance_of(String)

      o = resolved[7]
      expect(o).to be_an_instance_of(String)

      o = resolved[8]
      expect(o).to be_an_instance_of(String)

      o = resolved[9]
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d21.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
      expect(o.name).to eql('d21')

      o = resolved[10]
      expect(o).to be_an_instance_of(Fl::Core::List::Item)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d12.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
      expect(o.name).to eql('d12')
    end

    it 'should accept a nil owner argument' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      objects = [ l10.list_items.first,
                  d22.fingerprint, d22,
                  { listed_object: d22 }, { listed_object: d22.fingerprint },
                  { listed_object: d21, owner: a3, name: 'd21' },
                  { listed_object: d12, owner: a2, name: 'd12' }
                ]
      errcount, resolved = Fl::Core::List::Item.normalize_objects(objects, l10)
      expect(errcount).to eql(0)
      
      o = resolved[0]
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[1]
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[2]
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[3]
      expect(o.owner.fingerprint).to eql(d22.owner.fingerprint)

      o = resolved[4]
      expect(o.owner.fingerprint).to eql(d22.owner.fingerprint)

      o = resolved[5]
      expect(o.owner.fingerprint).to eql(a3.fingerprint)

      o = resolved[6]
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end

    context 'with a custom list class' do
      it 'should resolve correctly' do
        l10 = MyListOne.create(objects: [ d10, d20, d21, d11 ], owner: a1)
        l11 = MyListOne.create(objects: [ d10, d22, d20, d12 ], owner: a1)

        objects = [ l10.list_items.first,
                    d22.fingerprint, d22,
                    { listed_object: d22 }, { listed_object: d22.fingerprint },
                    l11.list_items.first,
                    d30, d30.fingerprint, { listed_object: d30 },
                    { listed_object: d21, owner: a3, name: 'd21' },
                    { listed_object: d12, owner: a2, name: 'd12' }
                  ]
        errcount, resolved = Fl::Core::List::Item.normalize_objects(objects, l10, a2)
        expect(errcount).to eql(4)
        
        o = resolved[0]
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d10.fingerprint)
        expect(o.owner.fingerprint).to eql(a1.fingerprint)

        o = resolved[1]
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)

        o = resolved[2]
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)

        o = resolved[3]
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)

        o = resolved[4]
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)

        o = resolved[5]
        expect(o).to be_an_instance_of(String)

        o = resolved[6]
        expect(o).to be_an_instance_of(String)

        o = resolved[7]
        expect(o).to be_an_instance_of(String)

        o = resolved[8]
        expect(o).to be_an_instance_of(String)

        o = resolved[9]
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d21.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)
        expect(o.name).to eql('d21')

        o = resolved[10]
        expect(o).to be_an_instance_of(MyListItemOne)
        expect(o.list.fingerprint).to eql(l10.fingerprint)
        expect(o.listed_object.fingerprint).to eql(d12.fingerprint)
        expect(o.owner.fingerprint).to eql(a2.fingerprint)
        expect(o.name).to eql('d12')
      end
    end
  end
end
