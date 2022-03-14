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

RSpec.describe Fl::Core::List::List, type: :model do
  def _caption(text)
    c = Fl::Core::ProseMirror::Helper.content(text)
    return { caption_html: c[:html], caption_json: c[:json] }
  end
  
  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }

  let(:d10) { create(:test_datum_one, owner: a1, content: '10') }
  let(:d11) { create(:test_datum_one, owner: a2, content: '11') }
  let(:d20) { create(:test_datum_two, owner: a2, content: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a1, content: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, content: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a1, content: '30') }
    
  describe 'validation' do
    it 'should succeed with empty attributes' do
      l1 = Fl::Core::List::List.new
      expect(l1.valid?).to eq(true)
    end

    it 'should fail with empty title and caption' do
      l1 = Fl::Core::List::List.new({ title: '' }.merge(_caption('')))
      expect(l1.valid?).to eq(false)
      expect(l1.errors.messages).to include(:title)
    end

    it 'should generate a default title before validation' do
      c = _caption('my caption')
      l1 = Fl::Core::List::List.new(c)
      expect(l1.title).to be_nil
      expect(l1.caption_html).to eql(c[:caption_html])
      expect(l1.valid?).to eq(true)
      expect(l1.title).to eql('my caption')
    end
  end

  describe '#initialize' do
    it 'should generate default values' do
      l1 = Fl::Core::List::List.new
      expect(l1.caption_html).to be_a_kind_of(String)
      expect(l1.caption_html.length).to be > 0
      expect(l1.caption_json).to be_a_kind_of(Hash)
      expect(l1.caption_json).to include("type" => "doc")
      expect(l1.default_item_state_locked).to eql(true)

      caption = 'the caption'
      c = _caption(caption)
      l1 = Fl::Core::List::List.new({ default_item_state_locked: false }.merge(c))
      expect(l1.caption_html).to eql(c[:caption_html])
      expect(l1.default_item_state_locked).to eql(false)
    end

    it 'should support the owner attribute' do
      l1 = Fl::Core::List::List.new(owner: a1)
      expect(l1.valid?).to be(true)
      expect(l1.owner).not_to be_nil
      expect(l1.owner.fingerprint).to eql(a1.fingerprint)
      
      l2 = Fl::Core::List::List.new(owner: a2.fingerprint)
      expect(l2.valid?).to be(true)
      expect(l2.owner).not_to be_nil
      expect(l2.owner.fingerprint).to eql(a2.fingerprint)

      l3 = Fl::Core::List::List.new(owner: a2.to_global_id)
      expect(l3.valid?).to be(true)
      expect(l3.owner).not_to be_nil
      expect(l3.owner.fingerprint).to eql(a2.fingerprint)

      l4 = Fl::Core::List::List.new(owner: a2.to_global_id.to_s)
      expect(l4.valid?).to be(true)
      expect(l4.owner).not_to be_nil
      expect(l4.owner.fingerprint).to eql(a2.fingerprint)
    end

    it 'should load the list of items' do
      l1 = Fl::Core::List::List.new(objects: [ d10, d20 ])

      # the count disparity here is because the list items are not yet saved
      
      expect(l1.valid?).to be(true)
      expect(l1.list_items.count).to eql(0)
      expect(l1.list_items.to_a.count).to eql(2)

      # We need to save the list so that the list items are also saved
      
      expect(l1.save).to be(true)
      expect(l1.list_items.count).to eql(2)
      expect(l1.list_items.to_a.count).to eql(2)

      dl = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(dl)).to match_array(obj_fingerprints([ d10, d20 ]))
    end

    it 'should support hash object descriptors' do
      l1 = Fl::Core::List::List.new(objects: [
                                           { listed_object: d10 },
                                           { listed_object: d20, owner: a2, name: 'd20' }
                                         ])

      expect(l1.save).to be(true)
      expect(l1.list_items.count).to eql(2)

      dl = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(dl)).to match_array(obj_fingerprints([ d10, d20 ]))

      lil = l1.list_items.to_a
      expect(lil[0].listed_object.fingerprint).to eql(d10.fingerprint)
      expect(lil[0].owner.fingerprint).to eql(d10.owner.fingerprint)
      expect(lil[0].name).to be_nil
      expect(lil[1].listed_object.fingerprint).to eql(d20.fingerprint)
      expect(lil[1].owner.fingerprint).to eql(a2.fingerprint)
      expect(lil[1].name).to eql('d20')
    end

    it 'should support object fingerprints' do
      l1 = Fl::Core::List::List.new(objects: [
                                           d10.fingerprint, 
                                           { listed_object: d20.fingerprint, owner: a2, name: 'd20' }
                                         ])

      expect(l1.save).to be(true)
      expect(l1.list_items.count).to eql(2)

      dl = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(dl)).to match_array(obj_fingerprints([ d10, d20 ]))

      lil = l1.list_items.to_a
      expect(lil[0].listed_object.fingerprint).to eql(d10.fingerprint)
      expect(lil[0].owner.fingerprint).to eql(d10.owner.fingerprint)
      expect(lil[0].name).to be_nil
      expect(lil[1].listed_object.fingerprint).to eql(d20.fingerprint)
      expect(lil[1].owner.fingerprint).to eql(a2.fingerprint)
      expect(lil[1].name).to eql('d20')
    end

    it 'should support GlobalIDs' do
      l1 = Fl::Core::List::List.new(objects: [
                                           d10.to_global_id, 
                                           { listed_object: d20.to_global_id, owner: a2, name: 'd20' }
                                         ])

      expect(l1.save).to be(true)
      expect(l1.list_items.count).to eql(2)

      dl = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(dl)).to match_array(obj_fingerprints([ d10, d20 ]))

      lil = l1.list_items.to_a
      expect(lil[0].listed_object.fingerprint).to eql(d10.fingerprint)
      expect(lil[0].owner.fingerprint).to eql(d10.owner.fingerprint)
      expect(lil[0].name).to be_nil
      expect(lil[1].listed_object.fingerprint).to eql(d20.fingerprint)
      expect(lil[1].owner.fingerprint).to eql(a2.fingerprint)
      expect(lil[1].name).to eql('d20')

      l1 = Fl::Core::List::List.new(objects: [
                                           d10.to_global_id.to_s, 
                                           { listed_object: d20.to_global_id.to_s, owner: a2, name: 'd20' }
                                         ])

      expect(l1.save).to be(true)
      expect(l1.list_items.count).to eql(2)

      dl = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(dl)).to match_array(obj_fingerprints([ d10, d20 ]))

      lil = l1.list_items.to_a
      expect(lil[0].listed_object.fingerprint).to eql(d10.fingerprint)
      expect(lil[0].owner.fingerprint).to eql(d10.owner.fingerprint)
      expect(lil[0].name).to be_nil
      expect(lil[1].listed_object.fingerprint).to eql(d20.fingerprint)
      expect(lil[1].owner.fingerprint).to eql(a2.fingerprint)
      expect(lil[1].name).to eql('d20')
    end

    it 'should raise an exception with a non-listable object' do
      exc = nil
      
      expect do
        begin
          l1 = Fl::Core::List::List.new(objects: [ d10, d30 ])
        rescue => x
          exc = x
          raise x
        end
      end.to raise_exception(Fl::Core::List::List::NormalizationError)

      expect(exc.errors.length).to eql(1)
    end

    it 'should set item sort order' do
      l1 = Fl::Core::List::List.new(objects: [ d10, d20 ])

      expect(l1.save).to be(true)
      sort_orders = l1.list_items.map { |li| li.sort_order }
      expect(sort_orders).to eql([ 0, 1 ])

      dl = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(dl)).to eql(obj_fingerprints([ d10, d20 ]))
    end
  end

  describe 'creation' do
    it 'should set the fingerprint attributes' do
      l1 = Fl::Core::List::List.new(objects: [ d10, d20 ], owner: a1)

      expect(l1.valid?).to eq(true)
      expect(l1.owner_fingerprint).to be_nil
      
      expect(l1.save).to eq(true)
      expect(l1.owner_fingerprint).to eql(l1.owner.fingerprint)
    end
  end

  describe '#update' do
    it 'should update the list of items' do
      c = _caption('the caption')
      l1 = Fl::Core::List::List.new({ objects: [ d20 ] }.merge(c))

      expect(l1.save).to be(true)
      expect(l1.caption_html).to eql(c[:caption_html])
      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d20 ]))

      c = _caption('new caption')
      expect(l1.update({ objects: [ d10, d20 ] }.merge(c))).to eql(true)
      expect(l1.caption_html).to eql(c[:caption_html])
      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d10, d20 ]))
    end

    it 'should support hash object descriptors' do
      l1 = Fl::Core::List::List.new(objects: [ d21 ])

      expect(l1.save).to eql(true)
      expect(l1.list_items.count).to eql(1)
      lil = l1.list_items.to_a
      expect(lil[0].listed_object.fingerprint).to eql(d21.fingerprint)
      expect(lil[0].owner.fingerprint).to eql(d21.owner.fingerprint)
      expect(lil[0].name).to be_nil
      
      expect(l1.update(objects: [
                         { listed_object: d10, name: 'd10' },
                         { listed_object: d20, owner: a2, name: 'd20' }
                       ])).to eql(true)

      expect(l1.list_items.count).to eql(2)
      lil = l1.list_items.to_a
      expect(lil[0].listed_object.fingerprint).to eql(d10.fingerprint)
      expect(lil[0].owner.fingerprint).to eql(d10.owner.fingerprint)
      expect(lil[0].name).to eql('d10')
      expect(lil[1].listed_object.fingerprint).to eql(d20.fingerprint)
      expect(lil[1].owner.fingerprint).to eql(a2.fingerprint)
      expect(lil[1].name).to eql('d20')
    end
    
    it 'should raise an exception with a non-listable object' do
      exc = nil
      c = _caption('my caption')
      l1 = Fl::Core::List::List.new({ objects: [ d20 ] }.merge(c))

      expect(l1.save).to be(true)
      expect(l1.caption_html).to eql(c[:caption_html])
      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d20 ]))

      c = _caption('new caption')
      
      expect do
        begin
          l1.update({ objects: [ d30, d20 ] }.merge(c))
        rescue => x
          exc = x
          raise x
        end
      end.to raise_exception(Fl::Core::List::List::NormalizationError)

      expect(exc.errors.length).to eql(1)
    end
    
    it 'should set item sort order' do
      c = _caption('my caption')
      l1 = Fl::Core::List::List.new({ objects: [ d20 ] }.merge(c))

      expect(l1.save).to be(true)

      c = _caption('new caption')
      expect(l1.update({ objects: [ d10, d20 ] }.merge(c))).to eql(true)
      sort_orders = l1.list_items.map { |li| li.sort_order }
      expect(sort_orders).to eql([ 0, 1 ])
    end
  end

  describe 'list subclass' do
    it 'should support subclassing of lists' do
      l1 = MyListOne.create(objects: [ d21, d10 ], owner: a1)

      expect(l1.persisted?).to eql(true)
      l1.list_items.each do |li|
        expect(li).to be_a(MyListItemOne)
      end
    end
  end
  
  describe '#item_factory' do
    it 'should create a list item instance' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

      li1 = l1.item_factory(listed_object: d11, owner: a2)
      expect(li1).to be_a(Fl::Core::List::Item)
      expect(li1.valid?).to eql(true)
      expect(li1.persisted?).to eql(false)
      expect(li1.list.fingerprint).to eql(l1.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
      expect(li1.owner.fingerprint).to eql(a2.fingerprint)

      ol = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d21, d10 ]))

      expect(li1.save).to eql(true)
      l1.list_items.reload
      ol = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d21, d10, d11 ]))
    end

    it 'should be customizable' do
      l1 = MyListOne.create(objects: [ d21, d10 ], owner: a1)

      li1 = l1.item_factory(listed_object: d11, owner: a2)
      expect(li1).to be_a(MyListItemOne)
      expect(li1.valid?).to eql(true)
      expect(li1.persisted?).to eql(false)
      expect(li1.list.fingerprint).to eql(l1.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
      expect(li1.owner.fingerprint).to eql(a2.fingerprint)

      ol = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d21, d10 ]))

      expect(li1.save).to eql(true)
      l1.list_items.reload
      ol = l1.list_items.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d21, d10, d11 ]))

      l1.list_items.each do |li|
        expect(li).to be_a(MyListItemOne)
      end
    end
  end
  
  describe '#find_list_item' do
    it 'should find an object in the list' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

      li = l1.find_list_item(d10)
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.list.fingerprint).to eql(l1.fingerprint)
      expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(li.sort_order).to eql(1)

      li = l1.find_list_item(d10.fingerprint)
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.list.fingerprint).to eql(l1.fingerprint)
      expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(li.sort_order).to eql(1)
    end

    it 'should not find an object not in the list' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

      li = l1.find_list_item(d20)
      expect(li).to be_nil
    end
  end

  describe 'object management' do
    context '#objects' do
      it 'should return the correct value' do
        l1 = Fl::Core::List::List.create(owner: a1)
        l2 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        o1 = l1.objects
        expect(o1.count).to eql(0)

        o2 = l2.objects
        expect(obj_fingerprints(o2)).to eql(obj_fingerprints([ d21, d10 ]))
      end
    end

    context '#add_object' do
      it 'should add an object' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        li = l1.add_object(d20)
        expect(li).to be_a(Fl::Core::List::Item)
        expect(l1.save).to eql(true)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10, d20 ]))
      end

      it 'should add an object with an item name' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        li = l1.add_object(d20, a2, 'item1')
        expect(li).to be_a(Fl::Core::List::BaseItem)
        expect(l1.save).to eql(true)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10, d20 ]))

        i = l1.find_list_item(d20)
        expect(li.fingerprint).to eql(i.fingerprint)
        expect(i.name).to eql('item1')
      end

      it 'should not add an object already in the list' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        li = l1.add_object(d21)
        expect(li).to be_a(Fl::Core::List::BaseItem)
        expect(l1.save).to eql(true)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10 ]))
      end

      it 'should add a non-listable object, but validation should fail' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        li = l1.add_object(d30)
        expect(li).to be_a(Fl::Core::List::BaseItem)
        expect(l1.save).to eql(false)
        expect(l1.errors.messages.keys).to include(:"list_items.listed_object", :objects)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10, d30 ]))
        l1.list_items.reload
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10 ]))
      end

      it 'should add an object with duplicate name, but validation should fail' do
        l1 = create(:list, objects: [ [ d21, a1, 'item1' ], [ d10, a2, 'item2' ] ], owner: a1)

        li = l1.add_object(d11, a2, 'item2')
        expect(li).to be_a(Fl::Core::List::BaseItem)
        expect(l1.save).to eql(false)
        expect(l1.errors.messages.keys).to include(:"list_items.name")
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10, d11 ]))
        l1.list_items.reload
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10 ]))
      end

      it 'should set the sort order for a new item' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)
        no = l1.next_sort_order

        li = l1.add_object(d20)
        expect(li).to be_a(Fl::Core::List::BaseItem)
        expect(l1.save).to eql(true)
        expect(li.sort_order).to eql(no)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10, d20 ]))
      end

      it 'should support custom item classes' do
        l1 = MyListOne.create(objects: [ d21, d10 ], owner: a1)

        li = l1.add_object(d20)
        expect(li).to be_a(MyListItemOne)
        expect(l1.save).to eql(true)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10, d20 ]))
      end
    end

    context '#remove_object' do
      it 'should remove an object' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)
        l2 = Fl::Core::List::List.create(objects: [ d22, d11, d21 ], owner: a1)

        l1.remove_object(d21)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d10 ]))
        expect(l1.save).to eql(true)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d10 ]))

        l2.remove_object(d11)
        expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d22, d21 ]))
        expect(l2.save).to eql(true)
        expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d22, d21 ]))
      end

      it 'should not remove an object that is not in the list' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        l1.remove_object(d20)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10 ]))
        expect(l1.save).to eql(true)
        expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10 ]))
      end
    end
  end

  describe '#next_sort_order' do
    it 'should return the correct value' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

      ord = l1.next_sort_order()
      expect(ord).to eql(2)
    end
  end

  describe '.build_query' do
    let(:l1) { Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1) }
    let(:l2) { Fl::Core::List::List.create(objects: [ d22, d20 ], owner: a1) }
    let(:l3) { Fl::Core::List::List.create(objects: [ d11 ], owner: a2) }
    let(:l4) { Fl::Core::List::List.create(objects: [ d20, d21, d22 ], owner: a3) }
    let(:l5) { Fl::Core::List::List.create(objects: [ d21 ], owner: a2) }
    let(:l6) { Fl::Core::List::List.create(objects: [ d10, d21, d22 ], owner: a1) }

    it 'should return all lists with default options' do
      # this statement triggers the list creation
      xl = [ l1, l2, l3, l4, l5, l6 ].reverse
      
      q = Fl::Core::List::List.build_query()
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))
    end

    it 'should support the :owners filter' do
      # this statement triggers the list creation
      xl = [ l1, l2, l3, l4, l5, l6 ]
      
      q = Fl::Core::List::List.build_query(filters: { owners: { only: a1 } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { only: a1.fingerprint } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { only: a1.to_global_id } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { only: a1.to_global_id.to_s } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { only: [ a3, a1.fingerprint ] } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l4, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { except: a2 } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l4, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { except: a2.fingerprint } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l4, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { except: a2.to_global_id } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l4, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { except: a2.to_global_id.to_s } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l6, l4, l2, l1 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { except: [ a3, a1.fingerprint ] } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l5, l3 ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { except: a2, only: a2.fingerprint } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ ]))
      
      q = Fl::Core::List::List.build_query(filters: { owners: { except: a2, only: [ a2.fingerprint, a3 ] } })
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l4 ]))
    end

    it 'should support order and pagination options' do
      # this statement triggers the list creation
      xl = [ l1, l2, l3, l4, l5, l6 ]
      
      q = Fl::Core::List::List.build_query(order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))

      q = Fl::Core::List::List.build_query(filters: { owners: { only: a1 } }, order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l1, l2, l6 ]))

      q = Fl::Core::List::List.build_query(filters: { owners: { only: a1 } }, order: 'id', limit: 2, offset: 1)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ l2, l6 ]))
    end
  end

  describe '#query_list_items' do
    let(:l1) { create(:list, objects: [ d21, d10 ], owner: a1) }
    let(:l2) { create(:list, objects: [ d11, d20, d21, d10 ], owner: a2) }

    it 'should return the full list with default options' do
      q = l1.query_list_items()
      ol = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d21, d10 ]))

      q = l2.query_list_items()
      ol = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d11, d20, d21, d10 ]))
    end

    it 'should ignore the :lists filter' do
      q = l1.query_list_items(filters: { lists: { only: l2 } })
      ol = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d21, d10 ]))

      q = l2.query_list_items(filters: { lists: { except: l2 } })
      ol = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d11, d20, d21, d10 ]))
    end

    it 'should accept additional options' do
      q = l1.query_list_items(order: 'sort_order DESC')
      ol = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d10, d21 ]))

      q = l2.query_list_items(order: 'sort_order ASC', offset: 1, limit: 2)
      ol = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d21, d20 ]))

      q = l2.query_list_items(filters: { listables: { only: [ d10, d11.to_global_id ] } })
      ol = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ol)).to match_array(obj_fingerprints([ d10, d11 ]))
    end
  end

  describe '#resolve_path' do
    let(:l1) { create(:list, objects: [ [ d21, a1, 'd21' ], [ d10, a2, 'd10' ] ], owner: a1) }
    let(:l2) { create(:list, objects: [ [ d20, a1, 'd20' ], [ d11, a1, 'd11' ], [ l1, a1, 'l1' ] ], owner: a2) }
    let(:l3) { create(:list, objects: [ [ d22, a1, 'd22' ], [ l2, a2, 'l2' ] ], owner: a2) }

    let(:l10) { create(:list, objects: [ [ d21, a1, 'D21' ], [ d10, a2, 'D10' ] ], owner: a1) }
    let(:l20) { create(:list, objects: [ [ d20, a1, 'D20' ], [ d11, a1, 'D11' ], [ l10, a1, 'L10' ] ], owner: a2) }
    let(:l30) { create(:list, objects: [ [ d22, a1, 'D22' ], [ l20, a2, 'L20' ] ], owner: a2) }
    
    it 'finds an existing item' do
      li = l1.resolve_path('d21')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d21.fingerprint)
      expect(li.name).to eql('d21')

      li = l2.resolve_path('d11')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d11.fingerprint)
      expect(li.name).to eql('d11')

      li = l2.resolve_path('l1/d10')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(li.name).to eql('d10')

      li = l3.resolve_path('l2/l1/d10')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(li.name).to eql('d10')

      li = l3.resolve_path('l2/l1')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(l1.fingerprint)
      expect(li.name).to eql('l1')

      li = l3.resolve_path('l2/d20')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d20.fingerprint)
      expect(li.name).to eql('d20')
    end

    it 'returns nil on an unknown path' do
      expect(l1.resolve_path('d210')).to be_nil
      expect(l2.resolve_path('l1/d100')).to be_nil
      expect(l3.resolve_path('l2/l10/d10')).to be_nil
      expect(l3.resolve_path('l20/l1')).to be_nil
    end

    it 'ignores spurious slashes' do
      expect(l1.resolve_path('/d21')).to be_a(Fl::Core::List::BaseItem)
      expect(l2.resolve_path('d11/')).to be_a(Fl::Core::List::BaseItem)
      expect(l2.resolve_path('l1////d10')).to be_a(Fl::Core::List::BaseItem)
      expect(l3.resolve_path('l2///l1/d10//')).to be_a(Fl::Core::List::BaseItem)
      expect(l3.resolve_path('l2\\l1')).to be_a(Fl::Core::List::BaseItem)
      expect(l3.resolve_path('l2\\\\d20')).to be_a(Fl::Core::List::BaseItem)
    end

    it 'supports backslashes' do
      expect(l1.resolve_path('\\d21')).to be_a(Fl::Core::List::BaseItem)
      expect(l2.resolve_path('d11\\')).to be_a(Fl::Core::List::BaseItem)
      expect(l2.resolve_path('l1\\d10')).to be_a(Fl::Core::List::BaseItem)
      expect(l3.resolve_path('l2\\\\l1\\d10\\\\')).to be_a(Fl::Core::List::BaseItem)
      expect(l3.resolve_path('l2\\l1')).to be_a(Fl::Core::List::BaseItem)
      expect(l3.resolve_path('l2\\\\d20')).to be_a(Fl::Core::List::BaseItem)
    end

    it 'is case sensitive' do
      expect(l1.resolve_path('D21')).to be_nil
      expect(l2.resolve_path('L1/d10')).to be_nil
      expect(l3.resolve_path('l2/L1/d10')).to be_nil
      expect(l3.resolve_path('l2/L1')).to be_nil

      expect(l10.resolve_path('d21')).to be_nil
      li = l10.resolve_path('D21')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d21.fingerprint)
      expect(li.name).to eql('D21')

      expect(l20.resolve_path('d11')).to be_nil
      li = l20.resolve_path('D11')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d11.fingerprint)
      expect(li.name).to eql('D11')

      expect(l20.resolve_path('l10/d10')).to be_nil
      li = l20.resolve_path('L10/D10')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(li.name).to eql('D10')

      expect(l30.resolve_path('l20/l10/d10')).to be_nil
      li = l30.resolve_path('L20/L10/D10')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(li.name).to eql('D10')

      expect(l30.resolve_path('l20/l10')).to be_nil
      li = l30.resolve_path('L20/L10')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(l10.fingerprint)
      expect(li.name).to eql('L10')

      expect(l30.resolve_path('l20/d20')).to be_nil
      li = l30.resolve_path('L20/D20')
      expect(li).to be_a(Fl::Core::List::BaseItem)
      expect(li.listed_object.fingerprint).to eql(d20.fingerprint)
      expect(li.name).to eql('D20')
    end
  end

  describe 'list as listable' do
    it 'can be added to a list' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)
      l2 = Fl::Core::List::List.create(objects: [ d20, d11, l1 ], owner: a2)

      expect(obj_fingerprints(l2.lists.to_a)).to eql(obj_fingerprints([ ]))
      expect(obj_fingerprints(l1.lists.to_a)).to eql(obj_fingerprints([ l2 ]))
    end
  end

  describe 'model hash support' do
    context '#to_hash' do
      it 'should track :verbosity' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        id_keys = [ :type, :api_root, :global_id, :fingerprint, :id ]
        h = l1.to_hash(a1, { verbosity: :id })
        expect(h.keys).to match_array(id_keys)

        ignore_keys = id_keys | [ ]
        h = l1.to_hash(a1, { verbosity: :ignore })
        expect(h.keys).to match_array(ignore_keys)

        minimal_keys = id_keys | [ :caption_html, :caption_json, :title, :owner, :default_item_state_locked,
                                   :list_display_preferences, :created_at, :updated_at ]
        h = l1.to_hash(a1, { verbosity: :minimal })
        expect(h.keys).to match_array(minimal_keys)

        standard_keys = minimal_keys | [ ]
        h = l1.to_hash(a1, { verbosity: :standard })
        expect(h.keys).to match_array(standard_keys)

        verbose_keys = standard_keys | [ :lists, :objects ]
        h = l1.to_hash(a1, { verbosity: :verbose })
        expect(h.keys).to match_array(verbose_keys)

        complete_keys = verbose_keys | [ ]
        h = l1.to_hash(a1, { verbosity: :complete })
        expect(h.keys).to match_array(complete_keys)
      end

      it 'should customize key lists' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)

        id_keys = [ :type, :api_root, :global_id, :fingerprint, :id ]
        h_keys = id_keys | [ :title ]
        h = l1.to_hash(a1, { verbosity: :id, include: [ :title ] })
        expect(h.keys).to match_array(h_keys)

        minimal_keys = id_keys | [ :caption_html, :caption_json, :title, :owner, :default_item_state_locked,
                                   :list_display_preferences, :created_at, :updated_at ]
        h_keys = minimal_keys - [ :owner, :title ]
        h = l1.to_hash(a1, { verbosity: :minimal, except: [ :owner, :title ] })
        expect(h.keys).to match_array(h_keys)
      end

      it 'should customize key lists for subobjects' do
        l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1)
        l2 = Fl::Core::List::List.create(objects: [ d20, d11, l1 ], owner: a2)

        id_keys = [ :type, :api_root, :global_id, :fingerprint, :id ]
        h = l1.to_hash(a1, { verbosity: :minimal, include: [ :lists, :objects ] })
        o_keys = id_keys + [ :name, :created_at, :updated_at ]
        b_keys = id_keys + [ ]
        l_keys = id_keys + [ ]
        expect(h[:owner].keys).to match_array(o_keys)
        expect(h[:objects][0].keys).to match_array(b_keys)
        expect(h[:lists][0].keys).to match_array(l_keys)

        h = l1.to_hash(a1, {
                         verbosity: :minimal,
                         include: [ :lists, :objects ],
                          to_hash: {
                            owner: { verbosity: :id },
                            lists: { verbosity: :id, include: :title },
                            objects: { verbosity: :minimal }
                          }
                        })
        o_keys = id_keys + [ ]
        b_keys = id_keys + [ :title, :content, :created_at, :updated_at ]
        l_keys = id_keys + [ :title ]
        expect(h[:owner].keys).to match_array(o_keys)
        expect(h[:objects][0].keys).to match_array(b_keys)
        expect(h[:lists][0].keys).to match_array(l_keys)
      end
    end
  end
end
