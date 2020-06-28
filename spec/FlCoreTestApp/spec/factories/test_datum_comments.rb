FactoryBot.define do
  sequence(:datum_comment_counter) { |n| "#{n}" }

  factory :test_datum_comment, class: Fl::Core::TestDatumComment do
    transient do
      datum_comment_counter { generate(:datum_comment_counter) }
    end
    
    title { "title for datum_comment.#{datum_comment_counter}" }
    content { "content for datum_comment.#{datum_comment_counter}" }
    num_comments { 0 }
  end
end
