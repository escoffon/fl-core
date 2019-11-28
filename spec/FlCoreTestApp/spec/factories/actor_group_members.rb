FactoryBot.define do
  sequence(:actor_group_member_counter) { |n| "#{n}" }

  factory :actor_group_member, class: 'Fl::Core::Actor::GroupMember' do
    transient do
      actor_group_member_counter { generate(:actor_group_member_counter) }
    end
  end
end
