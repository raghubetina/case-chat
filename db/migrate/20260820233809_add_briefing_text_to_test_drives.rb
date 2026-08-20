# What was actually sent, so a run can be read against it.
#
# The drive already snapshots the author's own system_prompt, which turned out
# to be about 39% of the text the model saw: the case background, the referral
# and share sections and the answering rules are all composed by
# ContactBriefing from rows the author edits elsewhere. Storing only the
# author's field meant the board could not show the prompt, and could not tell
# that a run had gone stale because a referral condition moved.
#
# Nullable: rows written before this have nothing to backfill from. Recomposing
# one now would render today's conditions against an old run, which is the
# exact confusion the snapshot exists to prevent.
class AddBriefingTextToTestDrives < ActiveRecord::Migration[8.1]
  def change
    add_column :test_drives, :briefing_text, :text
  end
end
