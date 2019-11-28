FactoryBot.define do
  sequence(:datum_four_counter) { |n| "#{n}" }

  factory :test_datum_four, class: Fl::Core::TestDatumFour do
    transient do
      datum_four_counter { generate(:datum_four_counter) }
    end
    
    title { "title for datum_four.#{datum_four_counter}" }
    content { "content for datum_four.#{datum_four_counter}" }
  end
end
