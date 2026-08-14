class AddModelChoiceToContacts < ActiveRecord::Migration[8.1]
  # Which model answers as this person, and how hard it thinks.
  #
  # Both null by default, meaning "whatever the deployment is set to". A case
  # is mostly people who can be answered cheaply plus one or two who carry the
  # argument, and paying for the expensive model on all of them is the waste
  # this exists to avoid.
  #
  # The model implies its provider — the catalogue owns that mapping — so there
  # is no separate provider column to contradict it.
  def change
    add_column :contacts, :model, :string
    add_column :contacts, :effort, :string
  end
end
