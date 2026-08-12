require "test_helper"

class ApplicationJobTest < ActiveSupport::TestCase
  test "jobs wait for the surrounding database transaction to commit" do
    assert ApplicationJob.enqueue_after_transaction_commit
  end
end
