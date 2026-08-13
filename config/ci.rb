# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Reproducibility: renamed app Dev Container", "ruby script/devcontainer_smoke.rb"
  step "Development: CSP exemption", "ruby script/development_csp_smoke.rb"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: JS dependency audit", "npm audit --audit-level=high"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Style: StandardRB", "bundle exec standardrb"

  step "Style: ERB (defaults + HardCodedString)", "bundle exec erb_lint --lint-all"
  step "Style: Biome JS/CSS", "npm run check"

  step "Schema: active_record_doctor", "env RAILS_ENV=test bin/rails active_record_doctor"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  step "Tests: System", "bin/rails test:system"

  step "Reproducibility: no generated diff", "git diff --exit-code" if ENV["CI"]

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
