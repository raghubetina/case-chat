require "application_system_test_case"

# The interactions a request test cannot reach.
#
# Every integration test in this suite POSTs straight to a controller with
# hand-built params, which means the form's own field names, Turbo, Stimulus,
# and the Action Cable broadcast are all untested by construction. That is not
# theoretical: the composer shipped emitting `body` while the controller
# required `message[body]`, so every send 400'd and Turbo silently discarded
# it. The request test passed the whole time, because it sent the params the
# controller wanted rather than the ones the form sends.
#
# These tests type into the real field and click the real button.
class StudentLoopTest < ApplicationSystemTestCase
  # In production a worker performs ContactReplyJob and the answer arrives over
  # Action Cable. The default test adapter only records the job, so the reply
  # would never arrive and the broadcast path would go untested — which is the
  # single most important thing on this page. :async runs it on a real thread
  # pool, the way a worker would.
  setup do
    @queue_adapter_before = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :async

    CaseSeeder::Vesta.new.call
    @case_study = CaseStudy.find_by!(join_code: CaseSeeder::Vesta::JOIN_CODE)
    @june = Contact.find_by!(case_study: @case_study, full_name: "June Ellery")
    @student = User.find_by!(email: "jordan@example.test")
    sign_in @student
  end

  teardown do
    ActiveJob::Base.queue_adapter = @queue_adapter_before
  end

  def sign_in(user)
    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: CaseSeeder::Vesta::PASSWORD
    find("form input[type=submit], form button[type=submit]").click
    assert_text I18n.t("cases.index.heading")
  end

  def open_thread_with(contact)
    visit case_path(@case_study)
    within("##{dom_id(contact)}") { click_on I18n.t("cases.start_thread") }
    assert_selector "#composer_form"
  end

  test "sending a message posts it and streams the contact's answer back" do
    open_thread_with @june

    fill_in "message_body", with: "Why are we considering takeout at all?"
    click_on I18n.t("threads.send")

    # The student's own message renders from the response...
    assert_text "Why are we considering takeout at all?"
    # ...and the contact's answer arrives over the Turbo Stream broadcast.
    assert_text(/June Ellery/, wait: 10)
    assert_selector "#transcript > div", minimum: 2, wait: 10

    assert_equal 2, Conversation.last.messages.count
    # The empty state must not sit above a conversation that has started.
    assert_no_selector "#thread_empty"
  end

  test "the composer clears after a successful send" do
    open_thread_with @june

    fill_in "message_body", with: "First question."
    click_on I18n.t("threads.send")
    assert_text "First question."

    assert_equal "", find("#message_body").value
  end

  test "an empty message is refused by the browser and never reaches the server" do
    open_thread_with @june

    assert_no_difference "Message.count" do
      click_on I18n.t("threads.send")
      assert_selector "#composer_form"
    end
  end

  test "the thread uses the full width rather than the centred column" do
    open_thread_with @june

    # The centred container would cap main's width well below the viewport.
    main_width = evaluate_script("document.getElementById('main-content').getBoundingClientRect().width")
    viewport_width = evaluate_script("document.documentElement.clientWidth")

    assert_in_delta viewport_width, main_width, 1,
      "the thread view must be full-bleed, not inside the centred container"
  end

  test "the signed-out landing page offers a way in" do
    click_on I18n.t("nav.sign_out")
    visit "/"

    assert_text I18n.t("home.tagline")
    assert_link I18n.t("nav.sign_in")
    assert_no_text "It works."
  end

  test "a signed-in visitor is sent to their cases rather than the landing page" do
    visit "/"

    assert_current_path cases_path
  end
end
