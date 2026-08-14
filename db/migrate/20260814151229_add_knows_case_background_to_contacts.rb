class AddKnowsCaseBackgroundToContacts < ActiveRecord::Migration[8.1]
  # A stakeholder who has not been told which case they are standing in will
  # invent one. Default true because that is almost always right: these are
  # people inside the situation the student is asking about.
  #
  # It is a toggle rather than a constant because the exception matters — an
  # outside supplier, a regulator, a customer who only knows their own end of
  # it. Handing them the case background makes them omniscient in a way that
  # quietly removes the reason the student was supposed to go and ask them.
  def change
    add_column :contacts, :knows_case_background, :boolean, default: true, null: false
  end
end
