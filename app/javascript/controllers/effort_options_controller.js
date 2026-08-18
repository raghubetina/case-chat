import { Controller } from "@hotwired/stimulus"

// Narrows the reasoning-effort select to the levels the chosen model accepts.
//
// Contact validates the pair on save, so an unsupported level was never going
// to reach a provider — but the select offered every level any catalogued model
// accepts, so an author could pick one and only learn it was wrong by saving.
// The map is rendered into a data attribute rather than fetched: it is small,
// it is already in hand when the page renders, and the CSP forbids the inline
// script that would otherwise carry it.
export default class extends Controller {
  static targets = ["model", "effort", "price"]
  static values = { efforts: Object, fallback: String, prices: Object }

  modelChanged() {
    const model = this.modelTarget.value

    if (this.hasPriceTarget) {
      // Formatted server-side, so currency and translation are not reimplemented here.
      this.priceTarget.textContent = this.pricesValue[model] ?? ""
    }

    const offered = this.effortsValue[model] || []
    if (offered.length === 0) return

    // Same three steps as ModelCatalogue.resolved_effort: keep what is chosen
    // if this model still offers it, else the deployment default, else first.
    const chosen = this.effortTarget.value
    const keep = offered.includes(chosen)
      ? chosen
      : offered.includes(this.fallbackValue)
        ? this.fallbackValue
        : offered[0]

    this.effortTarget.replaceChildren(
      ...offered.map((level) => {
        const option = document.createElement("option")
        option.value = level
        option.textContent = level
        option.selected = level === keep
        return option
      }),
    )
  }
}
