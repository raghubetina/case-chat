# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
# The Rails defaults are extended with common authentication, payment, and
# identity fields from the OWASP Logging Cheat Sheet's "Data to exclude" list,
# plus Case Chat's private author instructions and persisted provider payloads:
# https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html#data-to-exclude
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :card_number,
  :instructions, :system_prompt, :input_snapshot, :raw_response
]
