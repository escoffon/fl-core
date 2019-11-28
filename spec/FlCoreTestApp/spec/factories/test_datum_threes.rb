FactoryBot.define do
  sequence(:datum_three_counter) { |n| "#{n}" }

  factory :test_datum_three, class: Fl::Core::TestDatumThree do
    transient do
      datum_three_counter { generate(:datum_three_counter) }
    end
    
    title { "title for datum_three.#{datum_three_counter}" }
    content { "content for datum_three.#{datum_three_counter}" }
  end
end
