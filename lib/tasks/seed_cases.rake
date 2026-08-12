# Loads a real teaching case so the app can be exercised end to end.
#
# Vesta is an incomplete-information case: the recommendation reverses under
# defensible readings of facts nobody wrote down. That is exactly the shape
# Case Chat is for — each gap is knowledge one person holds, and the student
# only closes it by asking the right person the right question. The referral
# graph below is the case's own structure, not decoration: the expediter is
# reachable only through Marco, because in the case nobody ever thought to ask
# the expediter anything.
namespace :case_chat do
  desc "Load the Vesta teaching case (idempotent)"
  task seed_vesta: :environment do
    CaseSeeder::Vesta.new.call
  end
end
