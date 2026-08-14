class AddProviderCursorPositionToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :provider_cursor_position, :integer
    add_check_constraint :conversations,
      "(provider_cursor IS NULL) = (provider_cursor_position IS NULL)",
      name: "conversations_provider_cursor_complete",
      validate: false
    add_check_constraint :conversations,
      "provider_cursor_position IS NULL OR provider_cursor_position > 0",
      name: "conversations_provider_cursor_position_positive",
      validate: false
    add_check_constraint :conversations,
      "provider_cursor IS NULL OR btrim(provider_cursor) <> ''",
      name: "conversations_provider_cursor_present",
      validate: false
  end
end
