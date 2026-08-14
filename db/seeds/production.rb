# Teaching cases are not loaded on a deployed box unless you ask for them.
#
# Seeding creates accounts that can be signed into, so it stays opt-in: set
# SEED_DEMO_CASES on the service, and SEED_PASSWORD along with it, since the
# development passphrase is committed to this repository. CaseSeeder::Base
# refuses to run in production without the latter.
#
# db:prepare only seeds a database it just created, so this runs once on first
# boot. To load a case into a database that already exists, run
# `bin/rails case_chat:seed_cases` from a shell on the service.
return if ENV["SEED_DEMO_CASES"].blank?

Rake::Task["case_chat:seed_cases"].invoke
