require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

Fl::Core::List::Helper.make_listable(Fl::Core::TestDatumOne)
Fl::Core::List::Helper.make_listable(Fl::Core::TestDatumTwo)

RSpec.describe Fl::Core::List::List, type: :model do
  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }

  let(:d10) { create(:test_datum_one, owner: a1, content: '10') }
  let(:d11) { create(:test_datum_one, owner: a2, content: '11') }
  let(:d20) { create(:test_datum_two, owner: a2, content: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a1, content: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, content: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a1, content: '30') }

  describe '.traverse_containers' do
    it 'moves up the hierarchy' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1, title: 'l1')
      l2 = Fl::Core::List::List.create(objects: [ d20, d11, l1 ], owner: a2, title: 'l2')
      l3 = Fl::Core::List::List.create(objects: [ l2 ], owner: a2, title: 'l3')
      l4 = Fl::Core::List::List.create(objects: [ l3 ], owner: a2, title: 'l4')

      ctx = { levels: [ ] }
      rv = Fl::Core::List::Helper.traverse_containers(d21, ctx) do |listable, list, level, context|
        if context[:levels][level].is_a?(Array)
          context[:levels][level] << list.title
        else
          context[:levels][level] = [ list.title ]
        end
        true
      end
      expect(ctx[:levels]).to eql([ [l1.title ], [ l2.title ], [ l3.title ], [ l4.title ] ])

      ctx = { levels: [ ] }
      rv = Fl::Core::List::Helper.traverse_containers(l1, ctx) do |listable, list, level, context|
        if context[:levels][level].is_a?(Array)
          context[:levels][level] << list.title
        else
          context[:levels][level] = [ list.title ]
        end
        true
      end
      expect(ctx[:levels]).to eql([ [ l2.title ], [ l3.title ], [ l4.title ] ])

      ctx = { levels: [ ] }
      rv = Fl::Core::List::Helper.traverse_containers(l4, ctx) do |listable, list, level, context|
        if context[:levels][level].is_a?(Array)
          context[:levels][level] << list.title
        else
          context[:levels][level] = [ list.title ]
        end
        true
      end
      expect(ctx[:levels]).to eql([ ])
    end

    it 'returns nil with a missing block' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1, title: 'l1')
      l2 = Fl::Core::List::List.create(objects: [ d20, d11, l1 ], owner: a2, title: 'l2')
      l3 = Fl::Core::List::List.create(objects: [ l2 ], owner: a2, title: 'l3')
      l4 = Fl::Core::List::List.create(objects: [ l3 ], owner: a2, title: 'l4')

      ctx = { levels: [ ] }
      rv = Fl::Core::List::Helper.traverse_containers(l1, ctx)
      expect(rv).to be_nil
      expect(ctx).to eql({ levels: [ ] })
    end

    it 'handles forks in the hierarchy' do
      l1 = Fl::Core::List::List.create(objects: [ d21, d10 ], owner: a1, title: 'l1')
      l2 = Fl::Core::List::List.create(objects: [ d20, d11, l1 ], owner: a2, title: 'l2')
      l3 = Fl::Core::List::List.create(objects: [ l2, l1, d20 ], owner: a2, title: 'l3')
      l4 = Fl::Core::List::List.create(objects: [ l3 ], owner: a2, title: 'l4')
      l5 = Fl::Core::List::List.create(objects: [ l3 ], owner: a2, title: 'l5')
      l6 = Fl::Core::List::List.create(objects: [ l5 ], owner: a2, title: 'l6')

      ctx = { levels: [ ], tops: [ ] }
      rv = Fl::Core::List::Helper.traverse_containers(d21, ctx) do |listable, list, level, context|
        if context[:levels][level].is_a?(Array)
          context[:levels][level] << list.title
        else
          context[:levels][level] = [ list.title ]
        end

        if list.lists.count == 0
          context[:tops] << list.title unless context[:tops].include?(list.title)
        end
        true
      end
      expect(ctx[:levels]).to eql([ [ l1.title ], [ l2.title, l3.title ], [ l3.title, l4.title, l5.title ],
                                    [ l4.title, l5.title, l6.title ], [ l6.title ] ])
      expect(ctx[:tops]).to match_array([ l4.title, l6.title ])

      l10 = Fl::Core::List::List.create(objects: [ d22 ], owner: a1, title: 'l10')
      l20 = Fl::Core::List::List.create(objects: [ d22 ], owner: a2, title: 'l20')
      l30 = Fl::Core::List::List.create(objects: [ l10 ], owner: a2, title: 'l30')
      l40 = Fl::Core::List::List.create(objects: [ l30 ], owner: a2, title: 'l40')
      l50 = Fl::Core::List::List.create(objects: [ l20 ], owner: a2, title: 'l50')

      ctx = { levels: [ ], tops: [ ] }
      rv = Fl::Core::List::Helper.traverse_containers(d22, ctx) do |listable, list, level, context|
        if context[:levels][level].is_a?(Array)
          context[:levels][level] << list.title
        else
          context[:levels][level] = [ list.title ]
        end

        if list.lists.count == 0
          context[:tops] << list.title unless context[:tops].include?(list.title)
        end
        true
      end
      expect(ctx[:levels]).to eql([ [ l10.title, l20.title ], [ l30.title, l50.title ], [ l40.title ] ])
      expect(ctx[:tops]).to match_array([ l40.title, l50.title ])
    end
  end
end
