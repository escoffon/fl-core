class CreateFlCoreTestData < ActiveRecord::Migration[6.0]
  def change
    create_table :fl_core_test_datum_ones do |t|
      t.string		:title
      t.string		:content

      t.timestamps
    end

    create_table :fl_core_test_datum_twos do |t|
      t.string		:title
      t.string		:content

      # This is a reference to records in :fl_core_test_datum_ones
      t.references	:master

      t.timestamps
    end
  end
end
