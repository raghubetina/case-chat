class AddMessageToIntroductions < ActiveRecord::Migration[8.1]
  # Which turn a student met somebody on.
  #
  # The message carried the answer instead — one `introduced_contact_id`, so a
  # contact who introduced two people in a turn could only show one card, and
  # the second person joined the directory with nothing in the transcript
  # saying where they came from.
  #
  # Introductions are already unique per enrollment and contact, so hanging
  # them off the message gets the rest for free: a turn that re-names somebody
  # the student has already met creates no row and therefore draws no card,
  # which is right, because nothing was earned. This is the shape
  # DocumentShare has always had.
  def up
    add_reference :introductions, :message, type: :uuid, null: true,
      foreign_key: {on_delete: :nullify}, index: {algorithm: :concurrently}

    # Existing transcripts keep their cards. Match on the pair the message
    # recorded; SQL rather than the models because Message is about to stop
    # exposing the column this reads.
    #
    # Assured rather than batched: one introduction exists per person a student
    # has met, so this table is bounded by enrolments times cast size and is in
    # the thousands at the scale this app is being tested at. A batched
    # backfill would be the right answer on a table where that stops being
    # true.
    safety_assured do
      execute <<~SQL
        UPDATE introductions
        SET message_id = messages.id
        FROM messages, conversations
        WHERE messages.introduced_contact_id = introductions.contact_id
          AND messages.conversation_id = conversations.id
          AND conversations.enrollment_id = introductions.enrollment_id
      SQL
    end
  end

  def down
    remove_reference :introductions, :message
  end
end
