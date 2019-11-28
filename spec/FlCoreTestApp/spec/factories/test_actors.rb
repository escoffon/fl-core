FactoryBot.define do
  sequence(:actor_counter) { |n| "#{n}" }

  factory :test_actor, class: Fl::Core::TestActor do
    transient do
      actor_counter { generate(:actor_counter) }
    end
    
    name { "actor.#{actor_counter}" }
  end
end
