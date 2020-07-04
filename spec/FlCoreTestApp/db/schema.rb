# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_07_04_165314) do

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "fl_core_actor_group_members", force: :cascade do |t|
    t.string "title"
    t.text "note"
    t.integer "group_id"
    t.string "actor_type"
    t.integer "actor_id"
    t.string "actor_fingerprint"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["actor_fingerprint"], name: "fl_core_grp_memb_actor_fp_idx"
    t.index ["actor_type", "actor_id"], name: "fl_core_grp_memb_actor_idx"
    t.index ["group_id"], name: "fl_core_grp_memb_group_idx"
  end

  create_table "fl_core_actor_groups", force: :cascade do |t|
    t.string "name"
    t.text "note"
    t.string "owner_type"
    t.integer "owner_id"
    t.string "owner_fingerprint"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index "lower(name)", name: "fl_core_act_grp_name_u_idx", unique: true
    t.index ["owner_fingerprint"], name: "fl_core_act_grp_owner_fp_idx"
    t.index ["owner_type", "owner_id"], name: "fl_core_act_grp_owner_idx"
  end

  create_table "fl_core_comments", force: :cascade do |t|
    t.string "commentable_type"
    t.integer "commentable_id"
    t.string "commentable_fingerprint"
    t.string "author_type"
    t.integer "author_id"
    t.string "author_fingerprint"
    t.text "title"
    t.text "contents"
    t.text "contents_delta"
    t.integer "num_comments", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["author_fingerprint"], name: "fl_core_cmts_author_fp_idx"
    t.index ["author_type", "author_id"], name: "fl_core_cmts_author_ref_idx"
    t.index ["commentable_fingerprint"], name: "fl_core_cmts_cmtable_fp_idx"
    t.index ["commentable_type", "commentable_id"], name: "fl_core_cmts_cmtable_ref_idx"
  end

  create_table "fl_core_test_actor_twos", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "fl_core_test_actors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "fl_core_test_avatar_users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "fl_core_test_datum_attachments", force: :cascade do |t|
    t.string "title"
    t.integer "owner_id"
    t.string "value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id"], name: "index_fl_core_test_datum_attachments_on_owner_id"
  end

  create_table "fl_core_test_datum_comment_twos", force: :cascade do |t|
    t.string "content"
    t.integer "owner_id"
    t.text "grants"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id"], name: "index_fl_core_test_datum_comment_twos_on_owner_id"
  end

  create_table "fl_core_test_datum_comments", force: :cascade do |t|
    t.string "title"
    t.string "content"
    t.integer "owner_id"
    t.integer "num_comments"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id"], name: "index_fl_core_test_datum_comments_on_owner_id"
  end

  create_table "fl_core_test_datum_fours", force: :cascade do |t|
    t.string "title"
    t.string "content"
    t.integer "owner_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id"], name: "index_fl_core_test_datum_fours_on_owner_id"
  end

  create_table "fl_core_test_datum_ones", force: :cascade do |t|
    t.string "title"
    t.string "content"
    t.integer "owner_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id"], name: "index_fl_core_test_datum_ones_on_owner_id"
  end

  create_table "fl_core_test_datum_subs", force: :cascade do |t|
    t.string "title"
    t.string "content"
    t.integer "master_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["master_id"], name: "index_fl_core_test_datum_subs_on_master_id"
  end

  create_table "fl_core_test_datum_threes", force: :cascade do |t|
    t.string "title"
    t.string "content"
    t.integer "owner_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id"], name: "index_fl_core_test_datum_threes_on_owner_id"
  end

  create_table "fl_core_test_datum_twos", force: :cascade do |t|
    t.string "title"
    t.string "content"
    t.integer "owner_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id"], name: "index_fl_core_test_datum_twos_on_owner_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
end
