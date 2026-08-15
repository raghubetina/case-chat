class RemoveIntroducedContactFromMessages < ActiveRecord::Migration[8.1]
  # The second half of moving introductions onto the turn they happened on.
  #
  # AddMessageToIntroductions gave Introduction a message, backfilled from this
  # column, and Message stopped reading it. Every deployed process has been
  # serving code that ignores it since, which is the condition strong_migrations
  # asks for before the column goes.
  def change
    safety_assured do
      remove_reference :messages, :introduced_contact, type: :uuid,
        foreign_key: {to_table: :contacts, on_delete: :nullify}, index: true
    end
  end
end
