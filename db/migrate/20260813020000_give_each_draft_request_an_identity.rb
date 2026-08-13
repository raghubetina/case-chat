# Drafting takes about two minutes, so an author can ask for a second draft
# while the first is still running. Without a way to tell the two requests
# apart, whichever job finishes last wins: the author's newer instructions can
# be silently overwritten by an answer to their older ones.
#
# The token identifies one request. A job whose token no longer matches the row
# knows a newer request has replaced it and throws its answer away.
class GiveEachDraftRequestAnIdentity < ActiveRecord::Migration[8.1]
  def change
    add_column :case_drafts, :request_token, :uuid
  end
end
