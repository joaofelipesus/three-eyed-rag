# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_21_110105) do
# Could not dump table "note_embeddings_vector_chunks00" because of following StandardError
#   Unknown type '' for column 'rowid'


# Could not dump table "note_section_embeddings_vector_chunks00" because of following StandardError
#   Unknown type '' for column 'rowid'


  create_table "note_sections", force: :cascade do |t|
    t.string "checksum"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "follow_note_id"
    t.integer "note_id", null: false
    t.integer "previous_note_id"
    t.datetime "updated_at", null: false
    t.index ["follow_note_id"], name: "index_note_sections_on_follow_note_id"
    t.index ["note_id"], name: "index_note_sections_on_note_id"
    t.index ["previous_note_id"], name: "index_note_sections_on_previous_note_id"
  end

  create_table "note_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "note_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id"], name: "index_note_tags_on_note_id"
    t.index ["tag_id"], name: "index_note_tags_on_tag_id"
  end

  create_table "notes", force: :cascade do |t|
    t.string "checksum"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "last_embeded_at"
    t.datetime "last_updated_at"
    t.string "path", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  add_foreign_key "note_sections", "note_sections", column: "follow_note_id"
  add_foreign_key "note_sections", "note_sections", column: "previous_note_id"
  add_foreign_key "note_sections", "notes"
  add_foreign_key "note_tags", "notes"
  add_foreign_key "note_tags", "tags"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "note_embeddings", "vec0", ["note_id integer primary key", "embedding float[2560]"]
  create_virtual_table "note_section_embeddings", "vec0", ["note_section_id integer primary key", "embedding float[2560]"]
end
