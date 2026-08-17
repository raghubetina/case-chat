require "application_system_test_case"
require_relative "../models/domain_test_helper"

# Capture, not assertion. Drives the surfaces a reviewer needs to compare and
# writes a screenshot plus the measurements behind it to tmp/design/.
#
# Screenshots alone are not enough: an 8px difference in where a wordmark starts
# is invisible in a frame and obvious in a number. Every bug found by eye in this
# app so far was confirmed by measuring, so the reviewer gets both.
#
# Skipped unless asked for, because it produces files rather than verdicts.
class DesignCaptureTest < ApplicationSystemTestCase
  OUT = Rails.root.join("tmp/design")

  # What a reviewer compares across surfaces. Each entry is a name and the
  # selector that names it; missing ones are recorded as absent rather than
  # failing, since not every surface has every part.
  ANCHORS = {
    "chrome" => "#app-header, [role=search]",
    "wordmark" => "#app-header a, [role=search] a",
    "primary_action" => ".btn-primary",
    "secondary_action" => ".btn-outline",
    "heading" => "h1",
    "sidebar_row" => "#workspace-sidebar a.row-off, #workspace-sidebar a.row-on",
    "card" => "article",
    "field" => "input[type=text], input[type=search], input[type=email]",
    # The filled part of a bar, not its track. A reviewer given only the track
    # sees seven identical widths and reasonably concludes the bars are broken;
    # the track is meant to be identical, and the fill is what carries meaning.
    "meter_fill" => ".bg-accent[style*='width']"
  }.freeze

  setup do
    skip "set CAPTURE_SURFACES=1 to write design surfaces" unless ENV["CAPTURE_SURFACES"]
    FileUtils.mkdir_p(OUT)
    CaseSeeder::Meridian.new.call
    @case_study = CaseStudy.find_by!(join_code: CaseSeeder::Meridian::JOIN_CODE)
  end

  test "writes every surface a design review compares" do
    manifest = []

    manifest << capture("entry", "/login")

    sign_in_as_seeded("bob@example.com")
    manifest << capture("student_contacts", case_path(@case_study))
    manifest << capture("student_background", background_case_path(@case_study))

    sign_in_as_seeded("alice@example.com")
    # Not /author/cases: with a case in hand it redirects to the setup screen,
    # so capturing both wrote the same PNG twice and reported six surfaces while
    # reviewing five.
    manifest << capture("author_case_setup", edit_author_case_path(@case_study))
    manifest << capture("author_person_editor", edit_author_case_contact_path(@case_study, first_contact))
    manifest << capture("author_documents", author_case_documents_path(@case_study))
    manifest << capture("author_import", new_author_case_import_path(@case_study))
    manifest << capture("author_usage", author_case_usage_path(@case_study))
    manifest << capture("author_cohort", author_case_cohort_path(@case_study))

    File.write(OUT.join("measurements.json"), JSON.pretty_generate(manifest))
    puts "\nWrote #{manifest.size} surfaces to #{OUT}"
  end

  private

  def first_contact
    Contact.where(case_study: @case_study).order(:created_at).first
  end

  # Cookies rather than the sign-out control: there are two of those on a shell
  # page, and this is a capture tool, not a test of the logout flow.
  def sign_in_as_seeded(email)
    page.driver.browser.manage.delete_all_cookies
    visit "/login"
    fill_in "email", with: email
    fill_in "password", with: CaseSeeder::Base.password
    find("form input[type=submit], form button[type=submit]").click
    assert_no_selector "input[name=password]", wait: 5
  end

  def capture(name, path)
    visit path
    assert_selector "body"
    # Lint/Debugger reads save_screenshot as a stray debugging call. Here it is
    # the output.
    page.save_screenshot(OUT.join("#{name}.png").to_s) # standard:disable Lint/Debugger

    {surface: name, path: path, viewport: evaluate_script("window.innerWidth"), anchors: measure_anchors}
  end

  # Geometry and type for each anchor: where its glyphs start, how big it is, and
  # what it is set in. These are the numbers a spacing scale is supposed to keep
  # consistent and cannot by itself.
  def measure_anchors
    ANCHORS.transform_values do |selector|
      evaluate_script(<<~JS)
        (() => {
          const els = [...document.querySelectorAll(#{selector.to_json})]
            .filter(el => el.getBoundingClientRect().width > 0);
          return els.slice(0, 6).map(el => {
            const box = el.getBoundingClientRect();
            const cs = getComputedStyle(el);
            return {
              text: el.textContent.trim().slice(0, 24),
              textLeft: Math.round(box.left + parseFloat(cs.paddingLeft)),
              width: Math.round(box.width),
              height: Math.round(box.height),
              fontSize: cs.fontSize,
              fontWeight: cs.fontWeight,
              // Tracking and caps are what make this app's label tier a tier.
              // Without them a reviewer cannot tell a mark from a label.
              letterSpacing: cs.letterSpacing,
              textTransform: cs.textTransform,
              paddingY: cs.paddingTop + "/" + cs.paddingBottom
            };
          });
        })()
      JS
    end
  end
end
