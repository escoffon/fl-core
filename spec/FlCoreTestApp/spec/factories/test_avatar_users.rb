FactoryBot.define do
  sequence(:avatar_user_counter) { |n| "#{n}" }

  factory :test_avatar_user, class: 'Fl::Core::TestAvatarUser' do
    transient do
      avatar_user_counter { generate(:avatar_user_counter) }
    end
    
    name { "avatar_user.#{avatar_user_counter}" }
  end
end
