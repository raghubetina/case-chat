# The generated length validators (title <= 200, join_code <= 32) had no
# matching schema limits, which active_record_doctor flags in bin/ci. Empty
# tables and a narrowing that matches an already-enforced validator make this
# rewrite safe.
class AddStringLimitsMatchingValidators < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      change_column :case_studies, :title, :string, limit: 200
      change_column :case_studies, :join_code, :string, limit: 32
    end
  end

  def down
    safety_assured do
      change_column :case_studies, :title, :string
      change_column :case_studies, :join_code, :string
    end
  end
end
