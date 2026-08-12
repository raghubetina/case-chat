module FoundationPaginationHelper
  def foundation_pagy_nav(pagy)
    sanitize(
      pagy.series_nav(aria_label: t("foundation_domain.pagination.label")),
      tags: %w[nav a],
      attributes: %w[aria-current aria-disabled aria-label aria-keyshortcuts class data-pagy href rel role]
    )
  end
end
