class CreateFlCoreTestActors < ActiveRecord::Migration[6.0]
  def change
    # Object used for testing actors and owners.
    
    create_table :fl_core_test_actors do |t|
      t.string		:name

      t.timestamps
    end

    # Another actor to test actor support
    
    create_table :fl_core_test_actor_twos do |t|
      t.string		:name

      t.timestamps
    end
  end
end
