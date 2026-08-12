#!/usr/bin/env ruby

ENV["RAILS_ENV"] = "development"

require_relative "../config/environment"
require "rack/mock"

def assert_no_csp!(response, label)
  enforced = response["Content-Security-Policy"]
  report_only = response["Content-Security-Policy-Report-Only"]

  abort "#{label} unexpectedly carries an enforced CSP: #{enforced}" if enforced
  abort "#{label} unexpectedly carries a report-only CSP: #{report_only}" if report_only
end

request = Rack::MockRequest.new(Rails.application)
request_headers = {"HTTP_HOST" => "localhost", "REMOTE_ADDR" => "127.0.0.1"}

error_page = request.get("/development-csp-smoke-missing", request_headers)
abort "Expected a development error page to return 404, got #{error_page.status}" unless error_page.status == 404
abort "Expected web-console on the development error page" unless error_page.body.include?('data-template="console"')
assert_no_csp!(error_page, "Development error page")

puts "The development exception page omits CSP and includes web-console"
