class SnapshotThePersonOnATestDrive < ActiveRecord::Migration[8.1]
  # Two rehearsals are only comparable if you know what each one ran against.
  # Reading them side by side, the question is always "why did these differ" --
  # and a different model is only one of the answers. The other is that the
  # prompt was edited in between, which is invisible unless it is recorded.
  #
  # A snapshot on the drive rather than versioning Contact. Versioning would
  # answer "what did this person look like on Tuesday", which nobody asks; this
  # answers "what did this run use", which is the whole question. It is written
  # once, when the drive opens, and never updated -- a run is a fixed thing.
  #
  # The model and effort are not here: they are on the calls the drive made,
  # which is where the truth is if an author changes the model mid-run.
  def change
    add_column :test_drives, :system_prompt, :text
    add_column :test_drives, :role_title, :string
    add_column :test_drives, :knows_case_background, :boolean
  end
end
