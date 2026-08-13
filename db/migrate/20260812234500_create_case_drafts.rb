# A drafted case is a proposal the author reads before any of it becomes real.
# It gets a table rather than a cache entry because the author is expected to
# leave, think, and come back: a store that is allowed to evict would drop the
# proposal silently, and the author would have to pay for the draft again.
#
# The row also carries the state of the background work that produces it.
# Drafting from a full teaching PDF takes about two minutes against a real
# model, so it cannot run inside a request that must answer in fifteen seconds.
#
# The payload is the proposal, not the cast. Nothing in `contacts` or
# `referrals` exists until the author accepts.
class CreateCaseDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :case_drafts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :case_study, null: false, foreign_key: true, type: :uuid, index: {unique: true}
      t.integer :status, null: false, default: 0
      t.text :hint
      t.jsonb :payload
      t.timestamps
    end
  end
end
