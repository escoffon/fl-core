FactoryBot.define do
  sequence(:datum_two_counter) { |n| "#{n}" }

  factory :test_datum_two, class: Fl::Core::TestDatumTwo do
    transient do
      datum_two_counter { generate(:datum_two_counter) }
    end
    
    title { "title for datum_two.#{datum_two_counter}" }
    content { "content for datum_two.#{datum_two_counter}" }
  end
end
