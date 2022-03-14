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

RSpec.describe Fl::Core::List::Listable, type: :model do
  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }

  let(:d10_title) { 'd10 - title' }
  let(:d11_title) { 'd11 - title' }
  let(:d20_title) { 'd20 - title' }
  let(:d21_title) { 'd21 - title' }
  let(:d22_title) { 'd22 - title' }
  let(:d30_title) { 'd30 - title' }

  let(:d10) { create(:test_datum_one, owner: a1, content: '10', title: d10_title) }
  let(:d11) { create(:test_datum_one, owner: a2, content: '11', title: d11_title) }
  let(:d20) { create(:test_datum_two, owner: a2, content: 'v20', title: d20_title) }
  let(:d21) { create(:test_datum_two, owner: a1, content: 'v21', title: d21_title) }
  let(:d22) { create(:test_datum_two, owner: a1, content: 'v22', title: d22_title) }
  let(:d30) { create(:test_datum_three, owner: a1, content: '30', title: d30_title) }

  describe '#listable?' do
    it 'should be defined for all ActiveRecord classes' do
      expect(d10.methods).to include(:listable?)
      expect(d20.methods).to include(:listable?)
      expect(d30.methods).to include(:listable?)
    end

    it 'should return true for classes marked listable' do
      expect(d10.listable?).to eql(true)
      expect(d20.listable?).to eql(true)
      expect(d30.listable?).to eql(false)
    end
  end
  
  describe '#list_item_summary' do
    it 'should be defined for all ActiveRecord classes' do
      expect(d10.methods).to include(:list_item_summary)
      expect(d20.methods).to include(:list_item_summary)
      expect(d30.methods).to include(:list_item_summary)
    end

    it 'should call the correct summary method' do
      expect(d10.list_item_summary).to eql(d10.title)
      expect(d20.list_item_summary).to eql(d20.title)
      expect(d30.list_item_summary).to eql('')
    end
  end
  
  describe '#listable_containers' do
    it 'should return the correct list' do
      l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
      l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

      d10_c = d10.listable_containers
      d10_l = d10_c.map { |li| li.list.fingerprint }
      expect(d10_l).to contain_exactly(l1.fingerprint)
      d10_d = d10_c.map { |li| li.listed_object.fingerprint }
      expect(d10_d).to contain_exactly(d10.fingerprint)

      d20_c = d20.listable_containers
      d20_l = d20_c.map { |li| li.list.fingerprint }
      expect(d20_l).to contain_exactly(l1.fingerprint, l2.fingerprint)
      d20_d = d20_c.map { |li| li.listed_object.fingerprint }
      expect(d20_d).to contain_exactly(d20.fingerprint, d20.fingerprint)
    end

    it 'should remove a destroyed object from all lists' do
      l1 = create(:list, objects: [ d21, d10 ], owner: a1)
      l2 = create(:list, objects: [ d11, d20, d21, d10 ], owner: a2)

      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10 ]))
      expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d11, d20, d21, d10 ]))

      d10.destroy
      l1.reload
      l2.reload
      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21 ]))
      expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d11, d20, d21 ]))

      d11.destroy
      l1.reload
      l2.reload
      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21 ]))
      expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d20, d21 ]))
    end
  end

  describe 'list management' do
    context '#lists' do
      it 'should return the correct list' do
        l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        d10_l = d10.lists.map { |l| l.fingerprint }
        expect(d10_l).to contain_exactly(l1.fingerprint)

        d20_l = d20.lists.map { |l| l.fingerprint }
        expect(d20_l).to contain_exactly(l1.fingerprint, l2.fingerprint)
      end
    end
    
    context '#add_to_list' do
      it 'should add the listable' do
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        expect(obj_fingerprints(d10.lists)).to eql([ ])
        
        li = d10.add_to_list(l2, a1)
        expect(li).to be_an_instance_of(Fl::Core::List::Item)
        expect(li.list.fingerprint).to eql(l2.fingerprint)
        expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
        expect(li.owner.fingerprint).to eql(a1.fingerprint)
        expect(obj_fingerprints(d10.lists(true))).to contain_exactly(l2.fingerprint)
      end

      it 'should use the list owner if necessary' do
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])
        
        li = d10.add_to_list(l2)
        expect(li).to be_an_instance_of(Fl::Core::List::Item)
        expect(li.owner.fingerprint).to eql(l2.owner.fingerprint)
      end

      it 'should not add the listable if already in the list' do
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        expect(obj_fingerprints(d10.lists)).to eql([ ])
        
        li = d10.add_to_list(l2, a1)
        expect(li).to be_an_instance_of(Fl::Core::List::Item)
        expect(li.list.fingerprint).to eql(l2.fingerprint)
        expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
        expect(li.owner.fingerprint).to eql(a1.fingerprint)
        expect(obj_fingerprints(d10.lists(true))).to contain_exactly(l2.fingerprint)
        li_id = li.id
        
        li1 = d10.add_to_list(l2)
        expect(li1).to be_a(Fl::Core::List::Item)
        expect(li1.id).to eql(li_id)
        expect(obj_fingerprints(d10.lists(true))).to contain_exactly(l2.fingerprint)
      end

      it 'should support custom list classes' do
        l2 = MyListOne.create(owner: a2, objects: [ d20 ])

        expect(obj_fingerprints(d10.lists)).to eql([ ])
        
        li = d10.add_to_list(l2, a1)
        expect(li).to be_an_instance_of(MyListItemOne)
        expect(li.list.fingerprint).to eql(l2.fingerprint)
        expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
        expect(li.owner.fingerprint).to eql(a1.fingerprint)
        expect(obj_fingerprints(d10.lists(true))).to contain_exactly(l2.fingerprint)
      end
    end
    
    context '#remove_from_list' do
      it 'should remove the listable if in the list' do
        l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        expect(d10.remove_from_list(l1)).to eql(true)
        expect(obj_fingerprints(d10.lists(true))).to eql([ ])

        expect(d10.remove_from_list(l2)).to eql(false)
        expect(d10.remove_from_list(l1)).to eql(false)
      end
    end

    context '#in_list?' do
      it 'should find a listable in the list' do
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        li = d20.in_list?(l2)
        expect(li).to be_a(Fl::Core::List::BaseItem)
        expect(li.listed_object.fingerprint).to eql(d20.fingerprint)
        
        li = d10.add_to_list(l2, a1)
        expect(li).to be_an_instance_of(Fl::Core::List::Item)

        li = d10.in_list?(l2)
        expect(li).to be_a(Fl::Core::List::BaseItem)
        expect(li.listed_object.fingerprint).to eql(d10.fingerprint)
      end

      it 'should return nil if the listable is not in the list' do
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        li = d10.in_list?(l2)
        expect(li).to be_nil
      end
    end
  end

  describe 'item summary management' do
    it "should refresh item summaries after a save" do
      l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
      l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

      l1_s = l1.list_items.map { |li| li.item_summary }
      expect(l1_s).to match_array([ d10.title, d20.title ])
      l2_s = l2.list_items.map { |li| li.item_summary }
      expect(l2_s).to match_array([ d20.title ])

      d20_new_title = 'd20 - new title'
      d20.title = d20_new_title
      expect(d20.save).to eql(true)

      l1.list_items.reload
      l1_s = l1.list_items.map { |li| li.item_summary }
      expect(l1_s).to match_array([ d10.title, d20.title ])
      l2.list_items.reload
      l2_s = l2.list_items.map { |li| li.item_summary }
      expect(l2_s).to match_array([ d20_new_title ])
    end
  end
end
