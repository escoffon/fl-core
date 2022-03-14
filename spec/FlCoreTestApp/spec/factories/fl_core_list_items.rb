FactoryBot.define do
  sequence(:list_item_counter) { |n| "#{n}" }

  factory :list_item, class: 'Fl::Framework::List::ListItem' do
    transient do
      list_item_counter { generate(:list_item_counter) }
    end
  end
end
