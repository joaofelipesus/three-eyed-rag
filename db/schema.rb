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

ActiveRecord::Schema[8.1].define(version: 2026_07_14_110048) do
# Could not dump table "note_embeddings_vector_chunks00" because of following StandardError
#   Unknown type '' for column 'rowid'


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

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "note_embeddings", "vec0", ["note_id integer primary key", "embedding float[1024]"]
end
