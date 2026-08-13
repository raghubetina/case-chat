# A cast is addressed by name: referrals and share rules in a draft name the
# person they concern, and CaseImport keys on that. Two people with the same
# name inside one case makes those references ambiguous, and lets two
# simultaneous accepts of the same proposal each insert their own copy.
#
# The index is on lower(full_name) because the model's rule is
# case-insensitive, and a plain unique index would let "Dana Whitfield" and
# "dana whitfield" both exist — which is exactly the ambiguity being prevented.
#
# Referrals get the same treatment: the pair is the fact, and asserting it
# twice is not a second fact.
class GuaranteeOnePersonPerNameInACase < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :contacts, "case_study_id, lower(full_name)",
      unique: true, name: "index_contacts_on_case_study_id_and_lower_full_name",
      algorithm: :concurrently
    add_index :referrals, %i[referring_contact_id referred_contact_id],
      unique: true, algorithm: :concurrently

    # Both leading-column duplicates of the composite indexes above.
    remove_index :contacts, :case_study_id, algorithm: :concurrently
    remove_index :referrals, :referring_contact_id, algorithm: :concurrently
  end
end
