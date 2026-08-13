import { Controller } from "@hotwired/stimulus"

// The sidebar is permanent from md up and slides over the pane below that.
// Only the narrow case needs JS: the stylesheet's `[data-drawer="open"]` rule
// is itself inside a max-width query, so the attribute is inert on wide screens.
export default class extends Controller {
  static targets = ["toggle", "scrim"]

  open() {
    this.element.dataset.drawer = "open"
    this.#reflect(true)
  }

  close() {
    delete this.element.dataset.drawer
    this.#reflect(false)
  }

  #reflect(open) {
    for (const toggle of this.toggleTargets) {
      toggle.setAttribute("aria-expanded", open ? "true" : "false")
    }
    for (const scrim of this.scrimTargets) scrim.hidden = !open
  }
}
