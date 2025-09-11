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

ActiveRecord::Schema[8.0].define(version: 2025_09_05_131717) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_configurations", force: :cascade do |t|
    t.string "ai_model_name"
    t.string "api_endpoint"
    t.decimal "temperature"
    t.integer "max_tokens"
    t.integer "batch_size"
    t.integer "retry_attempts"
    t.decimal "cost_per_token"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cohorts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.bigint "user_id", null: false
    t.integer "max_students", default: 40, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_cohorts_on_user_id"
  end

  create_table "cost_trackings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "request_id"
    t.string "ai_model_used"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.decimal "cost_estimate"
    t.string "purpose"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_cost_trackings_on_user_id"
  end

  create_table "custom_attributes", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.boolean "inference_enabled"
    t.text "inference_prompt"
    t.decimal "weight_in_optimization"
    t.string "display_color"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "import_sessions", force: :cascade do |t|
    t.bigint "cohort_id", null: false
    t.bigint "user_id", null: false
    t.integer "status"
    t.string "file_name"
    t.integer "file_size"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "import_metadata"
    t.index ["cohort_id"], name: "index_import_sessions_on_cohort_id"
    t.index ["user_id"], name: "index_import_sessions_on_user_id"
  end

  create_table "inference_feedbacks", force: :cascade do |t|
    t.bigint "student_import_record_id", null: false
    t.string "field_name"
    t.string "original_inference"
    t.string "corrected_value"
    t.integer "feedback_type"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_import_record_id"], name: "index_inference_feedbacks_on_student_import_record_id"
    t.index ["user_id"], name: "index_inference_feedbacks_on_user_id"
  end

  create_table "interaction_trackings", force: :cascade do |t|
    t.bigint "student_a_id", null: false
    t.bigint "student_b_id", null: false
    t.bigint "seating_event_id", null: false
    t.integer "interaction_count", default: 0, null: false
    t.date "last_interaction"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "interaction_details", default: "[]"
    t.index "((interaction_details ->> 'day'::text))", name: "index_interaction_trackings_on_day"
    t.index ["interaction_details"], name: "index_interaction_trackings_on_interaction_details", using: :gin
    t.index ["seating_event_id"], name: "index_interaction_trackings_on_seating_event_id"
    t.index ["student_a_id", "student_b_id"], name: "index_interaction_trackings_on_student_a_id_and_student_b_id", unique: true
    t.index ["student_a_id"], name: "index_interaction_trackings_on_student_a_id"
    t.index ["student_b_id"], name: "index_interaction_trackings_on_student_b_id"
  end

  create_table "natural_language_instructions", force: :cascade do |t|
    t.bigint "seating_event_id", null: false
    t.text "instruction_text", null: false
    t.string "parsing_status", default: "pending"
    t.jsonb "parsed_rules", default: []
    t.jsonb "ai_interpretation", default: {}
    t.decimal "confidence_score", precision: 5, scale: 4, default: "0.0"
    t.bigint "created_by_id", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confidence_score"], name: "index_natural_language_instructions_on_confidence_score"
    t.index ["created_by_id"], name: "index_natural_language_instructions_on_created_by_id"
    t.index ["parsing_status"], name: "index_natural_language_instructions_on_parsing_status"
    t.index ["seating_event_id", "parsing_status"], name: "idx_on_seating_event_id_parsing_status_15e9673ea4"
    t.index ["seating_event_id"], name: "index_natural_language_instructions_on_seating_event_id"
  end

  create_table "seating_arrangements", force: :cascade do |t|
    t.bigint "seating_event_id", null: false
    t.jsonb "optimization_scores"
    t.jsonb "arrangement_data"
    t.bigint "created_by_id", null: false
    t.jsonb "diversity_metrics"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "explanation_data", default: {}
    t.jsonb "decision_log_data", default: {}
    t.jsonb "confidence_scores", default: {}
    t.datetime "last_modified_at"
    t.bigint "last_modified_by_id"
    t.boolean "is_locked", default: false
    t.bigint "locked_by_id"
    t.datetime "locked_at"
    t.integer "day_number"
    t.jsonb "multi_day_metadata", default: "{}"
    t.index ["confidence_scores"], name: "index_seating_arrangements_on_confidence_scores", using: :gin
    t.index ["created_by_id"], name: "index_seating_arrangements_on_created_by_id"
    t.index ["decision_log_data"], name: "index_seating_arrangements_on_decision_log_data", using: :gin
    t.index ["explanation_data"], name: "index_seating_arrangements_on_explanation_data", using: :gin
    t.index ["last_modified_by_id"], name: "index_seating_arrangements_on_last_modified_by_id"
    t.index ["locked_by_id"], name: "index_seating_arrangements_on_locked_by_id"
    t.index ["multi_day_metadata"], name: "index_seating_arrangements_on_multi_day_metadata", using: :gin
    t.index ["seating_event_id", "day_number"], name: "index_seating_arrangements_on_seating_event_id_and_day_number"
    t.index ["seating_event_id"], name: "index_seating_arrangements_on_seating_event_id"
  end

  create_table "seating_events", force: :cascade do |t|
    t.bigint "cohort_id", null: false
    t.string "name"
    t.integer "event_type"
    t.date "event_date"
    t.integer "table_size"
    t.integer "total_tables"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "multi_day_metrics", default: "{}"
    t.datetime "multi_day_optimization_completed_at"
    t.integer "multi_day_optimization_created_by"
    t.index ["cohort_id"], name: "index_seating_events_on_cohort_id"
    t.index ["multi_day_metrics"], name: "index_seating_events_on_multi_day_metrics", using: :gin
    t.index ["multi_day_optimization_completed_at"], name: "index_seating_events_on_multi_day_optimization_completed_at"
  end

  create_table "seating_instructions", force: :cascade do |t|
    t.bigint "seating_event_id", null: false
    t.text "instruction_text"
    t.jsonb "parsed_constraints"
    t.jsonb "ai_interpretation"
    t.boolean "applied"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seating_event_id"], name: "index_seating_instructions_on_seating_event_id"
  end

  create_table "seating_rules", force: :cascade do |t|
    t.bigint "seating_event_id", null: false
    t.string "rule_type", null: false
    t.text "natural_language_input", null: false
    t.jsonb "parsed_rule", default: {}
    t.decimal "confidence_score", precision: 5, scale: 4, default: "0.0"
    t.jsonb "target_attributes", default: {}
    t.jsonb "constraints", default: {}
    t.integer "priority", default: 1
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_seating_rules_on_active"
    t.index ["confidence_score"], name: "index_seating_rules_on_confidence_score"
    t.index ["priority"], name: "index_seating_rules_on_priority"
    t.index ["rule_type"], name: "index_seating_rules_on_rule_type"
    t.index ["seating_event_id", "active"], name: "index_seating_rules_on_seating_event_id_and_active"
    t.index ["seating_event_id"], name: "index_seating_rules_on_seating_event_id"
  end

  create_table "student_import_records", force: :cascade do |t|
    t.bigint "import_session_id", null: false
    t.bigint "student_id", null: false
    t.jsonb "raw_data"
    t.jsonb "ai_inferences"
    t.jsonb "corrections"
    t.boolean "feedback_provided"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_session_id"], name: "index_student_import_records_on_import_session_id"
    t.index ["student_id"], name: "index_student_import_records_on_student_id"
  end

  create_table "students", force: :cascade do |t|
    t.string "name"
    t.string "title"
    t.string "organization"
    t.string "location"
    t.bigint "cohort_id", null: false
    t.jsonb "student_attributes"
    t.jsonb "inferences"
    t.jsonb "confidence_scores"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cohort_id"], name: "index_students_on_cohort_id"
    t.index ["name", "cohort_id"], name: "index_students_on_name_and_cohort_id", unique: true
  end

  create_table "table_assignments", force: :cascade do |t|
    t.bigint "seating_arrangement_id", null: false
    t.bigint "student_id", null: false
    t.integer "table_number"
    t.integer "seat_position"
    t.boolean "locked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
    t.index ["seating_arrangement_id"], name: "index_table_assignments_on_seating_arrangement_id"
    t.index ["student_id"], name: "index_table_assignments_on_student_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "role", default: 0, null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cohorts", "users"
  add_foreign_key "cost_trackings", "users"
  add_foreign_key "import_sessions", "cohorts"
  add_foreign_key "import_sessions", "users"
  add_foreign_key "inference_feedbacks", "student_import_records"
  add_foreign_key "inference_feedbacks", "users"
  add_foreign_key "interaction_trackings", "seating_events"
  add_foreign_key "interaction_trackings", "students", column: "student_a_id"
  add_foreign_key "interaction_trackings", "students", column: "student_b_id"
  add_foreign_key "natural_language_instructions", "seating_events"
  add_foreign_key "natural_language_instructions", "users", column: "created_by_id"
  add_foreign_key "seating_arrangements", "seating_events"
  add_foreign_key "seating_arrangements", "users", column: "created_by_id"
  add_foreign_key "seating_arrangements", "users", column: "last_modified_by_id"
  add_foreign_key "seating_arrangements", "users", column: "locked_by_id"
  add_foreign_key "seating_events", "cohorts"
  add_foreign_key "seating_events", "users", column: "multi_day_optimization_created_by"
  add_foreign_key "seating_instructions", "seating_events"
  add_foreign_key "seating_rules", "seating_events"
  add_foreign_key "student_import_records", "import_sessions"
  add_foreign_key "student_import_records", "students"
  add_foreign_key "students", "cohorts"
  add_foreign_key "table_assignments", "seating_arrangements"
  add_foreign_key "table_assignments", "students"
end
