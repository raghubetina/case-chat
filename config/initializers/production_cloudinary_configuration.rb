require "uri"

module ProductionCloudinaryConfiguration
  module_function

  def validate!(environment)
    value = environment.fetch("CLOUDINARY_URL")
    raise KeyError, "CLOUDINARY_URL must not be blank" if value.strip.empty?

    uri = URI.parse(value)
    unless uri.scheme&.casecmp?("cloudinary") && uri.user.present? && uri.password.present? && uri.host.present?
      raise ArgumentError, "CLOUDINARY_URL must include an API key, API secret, and cloud name"
    end

    true
  rescue URI::InvalidURIError
    raise ArgumentError, "CLOUDINARY_URL must be a valid Cloudinary URL", cause: nil
  end

  def validate_on_boot!(environment, production:)
    return true unless production
    return true if environment["SECRET_KEY_BASE_DUMMY"].present?

    validate!(environment)
  end
end

ProductionCloudinaryConfiguration.validate_on_boot!(ENV, production: Rails.env.production?)
