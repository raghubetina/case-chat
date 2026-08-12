# The Foundation Plan carries these as required fields with defaults, but the
# current Compiler cannot render requiredness on non-short_text fields or
# authored defaults (github.com/firstdraft/firstdraft/issues/382), so they were
# deliberately left out of the generated schema. Restore them here; the
# matching model validations own the user-facing errors.
class AddDomainDefaultsAndNullConstraints < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    change_column_default :case_studies, :published, from: nil, to: false
    change_column_default :contacts, :in_starting_directory, from: nil, to: false
    change_column_default :referrals, :enabled, from: nil, to: true
    change_column_default :documents, :given_at_start, from: nil, to: false

    change_column_null :case_studies, :published, false
    change_column_null :contacts, :system_prompt, false
    change_column_null :contacts, :in_starting_directory, false
    change_column_null :referrals, :condition, false
    change_column_null :referrals, :enabled, false
    change_column_null :share_rules, :condition, false
    change_column_null :messages, :body, false
    change_column_null :messages, :sent_at, false
    change_column_null :messages, :from_contact, false
    change_column_null :documents, :given_at_start, false
  end
end
