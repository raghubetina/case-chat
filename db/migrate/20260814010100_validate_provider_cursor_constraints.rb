class ValidateProviderCursorConstraints < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :conversations, name: "conversations_provider_cursor_complete"
    validate_check_constraint :conversations, name: "conversations_provider_cursor_position_positive"
    validate_check_constraint :conversations, name: "conversations_provider_cursor_present"
  end
end
