class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # strict_loading_by_default guards read paths against N+1s, but dependent:
  # callbacks must lazily load exactly what they are about to destroy.
  # Teardown is not an N+1 to guard against; unmark each record for the
  # duration of its own destroy. Read-path strict_loading is unaffected.
  before_destroy prepend: true do
    strict_loading!(false)
  end
end
