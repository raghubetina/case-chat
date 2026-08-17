require "test_helper"

# The CSP grants style-src 'self' and a nonce, and a nonce cannot vouch for an
# attribute -- so a `style=` attribute is dropped in test and production while
# working perfectly in development, which has no CSP at all.
#
# That asymmetry shipped: the cohort's reach bars carried their width inline, so
# on the deployed site every bar rendered full, including the rows labelled 0%.
# It looked correct on every developer's machine.
class InlineStylePolicyTest < ActiveSupport::TestCase
  VIEWS = Rails.root.glob("app/views/**/*.erb")

  test "no view sets a style attribute the CSP will drop" do
    offenders = VIEWS.filter_map do |view|
      lines = view.read.lines.each_with_index.filter_map do |line, i|
        next if line.match?(/<%#/)
        "#{view.relative_path_from(Rails.root)}:#{i + 1}" if line.match?(/\bstyle:\s*"|\bstyle="/)
      end
      lines.presence
    end.flatten

    assert_empty offenders,
      "style attributes are dropped under the enforced CSP; move them to " \
      "application.tailwind.css:\n  #{offenders.join("\n  ")}"
  end
end
