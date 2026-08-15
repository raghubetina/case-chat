class CreateMessageReasonings < ActiveRecord::Migration[8.1]
  # The assistant turn exactly as the provider produced it, so the next turn can
  # hand it back and the model can keep reasoning from where it left off.
  #
  # Neither provider will do this for us. Anthropic is stateless by design and
  # asks callers to echo thinking blocks; on Claude Opus 5 those arrive with an
  # empty `thinking` string and a 628-character `signature`, and the signature
  # alone carries the continuity -- which is presumably why the adapter dropped
  # them as though they were empty. OpenAI can hold state server-side, but only
  # in exchange for a chain whose break is a hard error in front of a student,
  # and whose documented recovery is to resend the transcript anyway.
  #
  # A table of its own rather than a column on messages, for one reason: the
  # transcript view renders a message, and a test asserts a system prompt can
  # never appear there. Reasoning bytes that do not live on the record a view
  # renders cannot be rendered by accident.
  #
  # The model is stamped alongside because reasoning is tied to the model that
  # produced it. Handing Opus's blocks to Sonnet is not an error either provider
  # reports -- they are ignored, and the continuity silently disappears.
  def change
    create_table :message_reasonings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :message, type: :uuid, null: false,
        foreign_key: {on_delete: :cascade}, index: {unique: true}
      t.string :provider, null: false
      t.string :model, null: false
      t.jsonb :blocks, null: false, default: []

      t.timestamps
    end
  end
end
