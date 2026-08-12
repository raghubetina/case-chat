# Browser capabilities start closed and are widened deliberately by conditional
# layers (for example, an upload layer that needs camera access).
Rails.application.config.action_dispatch.default_headers["Permissions-Policy"] = [
  "camera=()",
  "geolocation=()",
  "microphone=()",
  "payment=()",
  "usb=()"
].join(", ")
