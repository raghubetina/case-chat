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

  // Following a link inside the drawer swaps the pane behind it; leaving the
  // drawer covering the thing you just asked for is the classic mobile bug.
  closeOnNavigate() {
    if (this.element.dataset.drawer === "open") this.close()
  }

  #reflect(open) {
    for (const toggle of this.toggleTargets) {
      toggle.setAttribute("aria-expanded", open ? "true" : "false")
    }
    for (const scrim of this.scrimTargets) scrim.hidden = !open
  }
}
