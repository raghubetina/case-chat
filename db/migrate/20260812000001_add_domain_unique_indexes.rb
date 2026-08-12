# Uniqueness the Compiler cannot express yet: join codes are typed by students
# to enter a case, and the three join tables each represent a fact that is
# either true once or not at all. The compound indexes make the existing
# single-column indexes on their leading columns redundant, so those go.
class AddDomainUniqueIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :case_studies, :join_code, unique: true
    add_index :introductions, [:enrollment_id, :contact_id], unique: true
    add_index :share_rules, [:contact_id, :document_id], unique: true
    add_index :document_shares, [:message_id, :document_id], unique: true

    remove_index :introductions, :enrollment_id
    remove_index :share_rules, :contact_id
    remove_index :document_shares, :message_id
  end
end
