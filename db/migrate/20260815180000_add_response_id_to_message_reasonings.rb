class AddResponseIdToMessageReasonings < ActiveRecord::Migration[8.1]
  # OpenAI keeps the turn for us; Anthropic does not.
  #
  # So the two providers need different things stored. Anthropic needs its
  # content blocks echoed back, which the blocks column already holds. OpenAI
  # needs only the id of the response it kept, plus the ids of any tool calls
  # that turn made, because a chained turn still has to answer them.
  def change
    add_column :message_reasonings, :response_id, :string
  end
end
