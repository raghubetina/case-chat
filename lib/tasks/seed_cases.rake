# Loads the teaching case so the app can be exercised end to end.
#
# Meridian is incomplete on purpose, which is the shape Case Chat is for. It
# withholds a judgment rather than a fact: every number is in the workbook on
# day one, and what the student has to earn is which of four people is
# describing the same figure differently, and which of them is wrong.
namespace :case_chat do
  desc "Load the Meridian vaccine allocation case (idempotent)"
  task seed_meridian: :environment do
    CaseSeeder::Meridian.new.call
  end

  desc "Load every teaching case (idempotent)"
  task seed_cases: %i[seed_meridian]
end
