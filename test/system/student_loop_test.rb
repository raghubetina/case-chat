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

  test "the pane fills everything the sidebar does not" do
    open_thread_with @june

    viewport = evaluate_script("document.documentElement.clientWidth")
    sidebar = evaluate_script("document.getElementById('workspace-sidebar').getBoundingClientRect().width")
    pane = evaluate_script("document.getElementById('main-content').getBoundingClientRect().width")

    assert_equal 272, sidebar.round, "the sidebar is a fixed 272px column"
    assert_in_delta viewport - sidebar, pane, 1,
      "the pane must take the rest of the viewport, not sit in a centred container"
  end

  test "the shell survives moving between panes" do
    visit case_path(@case_study)

    [
      [I18n.t("shell.panes.background"), background_case_path(@case_study)],
      [I18n.t("shell.panes.assignment"), assignment_case_path(@case_study)],
      [I18n.t("shell.panes.files"), files_case_path(@case_study)],
      [I18n.t("shell.panes.collected"), collected_case_path(@case_study)]
    ].each do |label, path|
      within("#workspace-sidebar") { click_on label }
      assert_current_path path

      # The whole point of a shell: the sidebar does not go away, and it says
      # where you are.
      assert_selector "#workspace-sidebar", text: @june.full_name
      assert_selector "#workspace-sidebar a[aria-current='page']", text: label
      assert_selector "h1", text: label
    end
  end

  test "a contact in the sidebar opens their thread from any pane" do
    open_thread_with @june
    visit files_case_path(@case_study)

    within("#workspace-sidebar") { click_on @june.full_name }

    assert_selector "#composer_form"
    assert_selector "h1", text: @june.full_name
    assert_selector "#workspace-sidebar [aria-current='page']", text: @june.full_name
  end

  test "search finds what was said and lists it in the sidebar" do
    open_thread_with @june
    fill_in "message_body", with: "Tell me about the takeout economics."
    click_on I18n.t("threads.send")
    assert_text "Tell me about the takeout economics."

    # Fill and submit as two independent queries: holding an element across
    # the navigation it triggers detaches the node mid-query.
    fill_in I18n.t("shell.search_label"), with: "takeout"
    click_on I18n.t("shell.search_submit")

    assert_current_path(/\/search\?/)
    # The sidebar stops being a map and becomes the result list.
    within("#workspace-sidebar") { assert_text "takeout" }
    assert_no_selector "#workspace-sidebar", text: I18n.t("shell.case_section")
  end

  test "search never reaches a conversation this run has not had" do
    other_run = Enrollment.create!(user: @student, case_study: @case_study)
    other = Conversation.create!(enrollment: other_run, contact: @june)
    other.messages.create!(body: "secret from another run", sent_at: Time.current, from_contact: false)

    first_run = Enrollment.where(user: @student, case_study: @case_study).newest_first.last
    visit search_case_path(@case_study, run: first_run.id, q: "secret")

    assert_no_text "secret from another run"
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
