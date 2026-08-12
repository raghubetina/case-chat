# A generous per-IP perimeter keeps a runaway client from monopolizing the app.
# Business limits on specific endpoints use Rails' built-in controller rate_limit.
#
# Counters use dedicated process memory so perimeter traffic cannot amplify
# load on the primary database. This free profile is deliberately one instance:
# counters reset on restart and are not shared. Multi-instance deployments must
# move rate limiting to an edge service or a dedicated shared cache.
require Rails.root.join("lib/perimeter_client_ip")

class Rack::Attack
  SAFELIST_PATHS = ["/up", "/ready"].freeze

  safelist("healthcheck and assets") do |req|
    SAFELIST_PATHS.include?(req.path) || req.path == "/assets" || req.path.start_with?("/assets/")
  end

  # 300 req / 5 min per IP — the conventional rack-attack general-traffic ceiling. A *sustained*
  # budget, so bursts (opening many tabs/links at once) are fine, and /assets + /up are safelisted.
  # Caveat: a classroom or office behind one NAT shares this budget — set RACK_ATTACK_LIMIT for
  # shared-IP audiences. The application config remains mutable so tests can exercise the boundary.
  throttle("requests by ip", limit: ->(_req) { Rails.application.config.x.rack_attack_limit }, period: 300) do |req|
    PerimeterClientIp.call(req)
  end

  self.throttled_responder = ->(request) do
    match_data = request.env["rack.attack.match_data"] || {}
    period = match_data.fetch(:period, 60).to_i
    epoch_time = match_data.fetch(:epoch_time, Time.now.to_i).to_i
    retry_after = period - (epoch_time % period)
    body = I18n.t("rate_limit.exceeded", seconds: retry_after)
    [429, {"content-type" => "text/plain; charset=utf-8", "retry-after" => retry_after.to_s}, ["#{body}\n"]]
  end
end

Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new(size: 8.megabytes)
Rails.application.config.x.rack_attack_limit = Integer(ENV.fetch("RACK_ATTACK_LIMIT", "300"), 10)
