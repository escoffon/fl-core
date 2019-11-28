FactoryBot.define do
  sequence(:actor_group_counter) { |n| "#{n}" }

  factory :actor_group, class: 'Fl::Core::Actor::Group' do
    transient do
      actor_group_counter { generate(:actor_group_counter) }
      actors { [ ] }
    end
    
    name { "name for actor_group.#{actor_group_counter}" }
    note { "note for actor_group.#{actor_group_counter}" }

    after(:build) do |actor_group, evaluator|
      evaluator.actors.each do |o|
        case o
        when ActiveRecord::Base
          actor_group.add_actor(o)
        when Array
          actor_group.add_actor(o[0], o[1], o[2])
        when Hash
          actor_group.add_actor(o[:actor], o[:title], o[:note])
        end
      end
    end
  end
end
