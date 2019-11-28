FactoryBot.define do
  sequence(:datum_sub_counter) { |n| "#{n}" }

  factory :test_datum_sub, class: Fl::Core::TestDatumSub do
    transient do
      datum_sub_counter { generate(:datum_sub_counter) }
    end
    
    title { "title for datum_sub.#{datum_sub_counter}" }
    content { "content for datum_sub.#{datum_sub_counter}" }
  end
end
