module CaseSeeder
  # Whether a deployed box was asked to load the teaching cases.
  #
  # Cast rather than test for presence: seeding creates accounts that can be
  # signed into, and the obvious way to turn that off is to set the flag to
  # "false", which a presence check reads as on.
  def self.requested?
    ActiveModel::Type::Boolean.new.cast(ENV["SEED_DEMO_CASES"])
  end
end
