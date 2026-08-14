require "test_helper"

class TestDrivePolicyTest < ActiveSupport::TestCase
  test "allows only the case author to create a test drive" do
    author = create_user
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    candidate = TestDrive.new(author:, stakeholder:)

    assert TestDrivePolicy.new(author, candidate).create?
    refute TestDrivePolicy.new(create_user, candidate).create?
    refute TestDrivePolicy.new(nil, candidate).create?
  end

  test "allows only the owner to view reset and discard a test drive" do
    author = create_user
    test_drive = start_test_drive(author:)
    author_policy = TestDrivePolicy.new(author, test_drive)
    other_policy = TestDrivePolicy.new(create_user, test_drive)

    %i[show? reset? destroy?].each do |query|
      assert author_policy.public_send(query), "expected the author to be allowed to #{query}"
      refute other_policy.public_send(query), "expected another user to be denied #{query}"
    end
  end

  test "scopes test drives to their author" do
    author = create_user
    own_test_drive = start_test_drive(author:)
    start_test_drive(author: create_user)

    assert_equal [own_test_drive.id],
      TestDrivePolicy::Scope.new(author, TestDrive.all).resolve.pluck(:id)
    assert_empty TestDrivePolicy::Scope.new(nil, TestDrive.all).resolve
  end

  private

  def start_test_drive(author:)
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    TestDrives::Start.call(
      author:,
      stakeholder_id: stakeholder.id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )
  end
end
