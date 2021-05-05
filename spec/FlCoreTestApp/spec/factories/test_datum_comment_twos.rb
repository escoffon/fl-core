require 'fl/core/comment'

FactoryBot.define do
  sequence(:datum_comment_two_counter) { |n| "#{n}" }

  factory :test_datum_comment_two, class: Fl::Core::TestDatumCommentTwo do
    transient do
      datum_comment_two_counter { generate(:datum_comment_two_counter) }
    end
    
    content { "content for datum_comment.#{datum_comment_two_counter}" }
    grants { { } }
  end
end
