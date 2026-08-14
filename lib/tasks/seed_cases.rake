# Loads real teaching cases so the app can be exercised end to end.
#
# Both cases below are incomplete on purpose, which is the shape Case Chat is
# for: each gap is knowledge one person holds, and the student only closes it by
# asking the right person the right question.
#
# They are incomplete in different ways, and the difference is worth knowing.
# Vesta withholds a fact — the recommendation reverses on what the kitchen does
# at eight o'clock on a Friday, and the expediter who knows is reachable only
# after Marco concedes he does not know his own kitchen. Meridian withholds a
# judgment: every number is in the workbook on day one, and what the student has
# to earn is which of four people is describing the same figure differently, and
# which of them is wrong.
namespace :case_chat do
  desc "Load the Vesta teaching case (idempotent)"
  task seed_vesta: :environment do
    CaseSeeder::Vesta.new.call
  end

  desc "Load the Meridian vaccine allocation case (idempotent)"
  task seed_meridian: :environment do
    CaseSeeder::Meridian.new.call
  end

  desc "Load every teaching case (idempotent)"
  task seed_cases: %i[seed_vesta seed_meridian]
end
