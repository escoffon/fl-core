class CreateFlCoreTestData < ActiveRecord::Migration[6.0]
  def change
    create_table :fl_core_test_datum_ones do |t|
      t.string		:title
      t.string		:content
      t.references	:owner

      t.timestamps
    end

    create_table :fl_core_test_datum_subs do |t|
      t.string		:title
      t.string		:content

      # This is a reference to records in :fl_core_test_datum_ones
      t.references	:master

      t.timestamps
    end

    create_table :fl_core_test_datum_twos do |t|
      t.string		:title
      t.string		:content
      t.references	:owner

      t.timestamps
    end

    create_table :fl_core_test_datum_threes do |t|
      t.string		:title
      t.string		:content
      t.references	:owner

      t.timestamps
    end

    create_table :fl_core_test_datum_fours do |t|
      t.string		:title
      t.string		:content
      t.references	:owner

      t.timestamps
    end

    create_table :fl_core_test_datum_comments do |t|
      t.string		:title
      t.string		:content
      t.references	:owner
      t.integer		:num_comments
      
      t.timestamps
    end

    create_table :fl_core_test_datum_comment_twos do |t|
      t.string		:content
      t.references	:owner
      t.text		:grants
      
      t.timestamps
    end
  end
end
