FactoryBot.define do
  sequence(:list_counter) { |n| "#{n}" }

  factory :list, class: 'Fl::Core::List::List' do
    transient do
      list_counter { generate(:list_counter) }
      objects { [ ] }
    end
    
    title { "list title - #{list_counter}" }
    caption_html { Fl::Core::ProseMirror::Helper.content("list caption - #{list_counter}")[:html] }
    caption_json { Fl::Core::ProseMirror::Helper.content("list caption - #{list_counter}")[:json] }

    after(:build) do |list, evaluator|
      evaluator.objects.each do |o|
        case o
        when ActiveRecord::Base
          list.add_object(o)
        when Array
          list.add_object(o[0], o[1], o[2])
        when Hash
          list.add_object(o[:obj], o[:owner], o[:name])
        end          
      end
    end
  end
end
