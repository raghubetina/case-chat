class ApplicationMailer < ActionMailer::Base
  register_interceptor NonProductionMailInterceptor unless Rails.env.production?

  default from: -> { Rails.configuration.x.mail_from }
  layout "mailer"
end
