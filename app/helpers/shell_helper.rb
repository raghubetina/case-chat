# The shell's sidebar is the app's primary navigation, so "which pane am I
# looking at" is decided in one place rather than re-derived in every row.
module ShellHelper
  # Panes are reached by ordinary GET, so the current one is simply the URL you
  # are on. No controller/action matching, and no state to keep in sync.
  def sidebar_row(label, path, count: nil)
    here = current_page?(path)

    link_to path, aria: {current: ("page" if here)},
      class: "flex items-center gap-3 rounded-md px-2 py-2 text-left text-sm #{here ? "row-on" : "row-off"}" do
      safe_join([label, (tag.span(count, class: "kick ml-auto text-xs text-faint") if count)].compact)
    end
  end

  # Every pane keeps you in the run you were reading. Without this, stepping
  # from a past run's thread into its Case files would silently jump you back to
  # the live one.
  def run_param
    params[:run].presence
  end

  # The chrome every student pane shares. Panes differ in their body and their
  # header, never in the shell around them.
  def student_shell
    {
      sidebar: "cases/sidebar",
      banner: "cases/run_banner",
      search_url: search_case_path(@case_study, run: run_param),
      search_scope: @case_study.title
    }
  end

  def author_shell
    {
      sidebar: "author/shared/sidebar",
      search_url: search_author_case_path(@case_study),
      search_scope: @case_study.title
    }
  end
end
