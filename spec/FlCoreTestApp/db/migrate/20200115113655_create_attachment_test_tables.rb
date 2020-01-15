class CreateAttachmentTestTables < ActiveRecord::Migration[6.0]
  def change
    # A user object that will have an avatar attachment.
    
    create_table :fl_core_test_avatar_users do |t|
      t.string		:name

      t.timestamps
    end

    # A data object that will have two attachments.
    
    create_table :fl_core_test_datum_attachments do |t|
      t.string		:title
      t.references	:owner
      t.string		:value

      t.timestamps
    end
  end
end
