class CreateFlCoreComments < ActiveRecord::Migration[6.0]
  def change
    create_table :fl_core_comments do |t|
      # Polymorphic reference to the commentable (object to which the comment is attached)
      # The commentable_fingerprint field is a query optimization
      t.references	:commentable, polymorphic: true, index: { name: 'fl_core_cmts_cmtable_ref_idx' }
      t.string		:commentable_fingerprint, index: { name: 'fl_core_cmts_cmtable_fp_idx' }

      # Polymorphic reference to the comment's author (and therefore owner)
      # The author_fingerprint field is a query optimization
      t.references	:author, polymorphic: true, index: { name: 'fl_core_cmts_author_ref_idx' }
      t.string		:author_fingerprint, index: { name: 'fl_core_cmts_author_fp_idx' }

      # Comment properties
      # :contents is the HTML representation of the contents, and :contents_delta the Delta representation
      # (as a serialized JSON field). See the Quill editor documentation for a discussion of Delta format
      t.text		:title
      t.text		:contents
      t.text		:contents_delta

      # Comment counter; comments track the number of their subcomments
      t.integer		:num_comments, default: 0

      t.timestamps
    end

    reversible do |o|
      o.up do
      end

      o.down do
      end
    end
  end
end
