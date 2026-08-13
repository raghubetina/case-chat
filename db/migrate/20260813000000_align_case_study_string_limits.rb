class AlignCaseStudyStringLimits < ActiveRecord::Migration[8.1]
  def up
    raise "case_studies.title contains a value longer than 200 characters" if maximum_length(:title) > 200
    raise "case_studies.join_code contains a value longer than 32 characters" if maximum_length(:join_code) > 32

    safety_assured do # Pre-launch and empty in production; the brief rewrite is safe here.
      change_column :case_studies, :title, :string, limit: 200, null: false
      change_column :case_studies, :join_code, :string, limit: 32
    end
  end

  def down
    change_column :case_studies, :title, :string, limit: nil, null: false
    change_column :case_studies, :join_code, :string, limit: nil
  end

  private

  def maximum_length(column)
    select_value("SELECT MAX(length(#{quote_column_name(column)})) FROM case_studies").to_i
  end
end
