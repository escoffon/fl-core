FactoryBot.define do
  sequence(:datum_one_counter) { |n| "#{n}" }

  factory :test_datum_one, class: Fl::Core::TestDatumOne do
    transient do
      datum_one_counter { generate(:datum_one_counter) }
    end
    
    title { "title for datum_one.#{datum_one_counter}" }
    content { "content for datum_one.#{datum_one_counter}" }
  end
end
