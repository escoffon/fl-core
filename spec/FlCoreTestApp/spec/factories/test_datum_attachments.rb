FactoryBot.define do
  sequence(:datum_attachment_counter) { |n| "#{n}" }

  factory :test_datum_attachment, class: 'Fl::Core::TestDatumAttachment' do
    transient do
      datum_attachment_counter { generate(:datum_attachment_counter) }
    end
    
    title { "datum_attachment title.#{datum_attachment_counter}" }
    value { "v: #{100 + datum_attachment_counter.to_i}" }
  end
end
