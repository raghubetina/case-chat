class AddFoundationDomainReferenceForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key "case_studies", "users", column: "author_id", on_delete: :restrict
    add_foreign_key "enrollments", "users", column: "user_id", on_delete: :cascade
    add_foreign_key "enrollments", "case_studies", column: "case_study_id", on_delete: :cascade
    add_foreign_key "contacts", "case_studies", column: "case_study_id", on_delete: :cascade
    add_foreign_key "referrals", "contacts", column: "referring_contact_id", on_delete: :cascade
    add_foreign_key "referrals", "contacts", column: "referred_contact_id", on_delete: :cascade
    add_foreign_key "share_rules", "contacts", column: "contact_id", on_delete: :cascade
    add_foreign_key "share_rules", "documents", column: "document_id", on_delete: :cascade
    add_foreign_key "documents", "case_studies", column: "case_study_id", on_delete: :cascade
    add_foreign_key "introductions", "enrollments", column: "enrollment_id", on_delete: :cascade
    add_foreign_key "introductions", "contacts", column: "contact_id", on_delete: :cascade
    add_foreign_key "introductions", "contacts", column: "introducing_contact_id", on_delete: :nullify
    add_foreign_key "conversations", "enrollments", column: "enrollment_id", on_delete: :cascade
    add_foreign_key "conversations", "contacts", column: "contact_id", on_delete: :cascade
    add_foreign_key "messages", "conversations", column: "conversation_id", on_delete: :cascade
    add_foreign_key "messages", "contacts", column: "introduced_contact_id", on_delete: :nullify
    add_foreign_key "document_shares", "messages", column: "message_id", on_delete: :cascade
    add_foreign_key "document_shares", "documents", column: "document_id", on_delete: :cascade
  end
end
