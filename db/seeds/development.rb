# A real teaching case, so development is exercised against real material
# rather than lorem ipsum. Idempotent: safe to re-run.
Rake::Task["case_chat:seed_vesta"].invoke
