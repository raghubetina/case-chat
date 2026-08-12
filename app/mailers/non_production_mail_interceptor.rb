class NonProductionMailInterceptor
  DEFAULT_SAFE_RECIPIENTS = %w[example.com example.test].freeze

  def self.delivering_email(message)
    recipients = [message.to, message.cc, message.bcc].flatten.compact
    return if recipients.all? { |recipient| safe_recipient?(recipient) }

    message.header["X-Intercepted-To"] = recipients.join(", ")
    message.to = [ENV.fetch("EMAIL_INTERCEPTOR_ADDRESS", "developer@example.test")]
    message.cc = nil
    message.bcc = nil
  end

  def self.safe_recipient?(recipient)
    address = Mail::Address.new(recipient).address.downcase
    domain = address.split("@", 2).last
    safelist = DEFAULT_SAFE_RECIPIENTS + ENV.fetch("EMAIL_SAFELIST", "").split(",")
    safelist.map! { it.strip.downcase }
    safelist.include?(address) || safelist.include?(domain)
  rescue Mail::Field::ParseError
    false
  end
  private_class_method :safe_recipient?
end
