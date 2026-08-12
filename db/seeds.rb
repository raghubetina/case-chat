# Seeds run in EVERY environment (bin/rails db:seed, and db:prepare on first boot).
# Keep entries idempotent (find_or_create_by!, upsert) so db:seed:replant and repeat
# runs are safe. Reference/lookup data belongs here.
#
# Development-only sample data belongs in db/seeds/development.rb, loaded below.
dev_seeds = Rails.root.join("db/seeds/#{Rails.env}.rb")
load(dev_seeds) if dev_seeds.exist?
