FactoryBot.define do
  sequence(:actor_two_counter) { |n| "#{n}" }

  factory :test_actor_two, class: Fl::Core::TestActorTwo do
    transient do
      actor_two_counter { generate(:actor_two_counter) }
    end
    
    name { "actor_two.#{actor_two_counter}" }
  end
end
