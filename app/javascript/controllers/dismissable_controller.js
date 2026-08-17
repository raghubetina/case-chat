import { Controller } from "@hotwired/stimulus"

// Matches the .flash-leaving transition in application.tailwind.css.
const LEAVE_MS = 160

// A confirmation dismisses itself; an error does not. That split is the one
// thing every source on this agrees about: a message someone has to read in
// order to fix something must not vanish on a timer. Errors therefore arrive
// without an `after` value and stay until dismissed.
//
// The timer pauses under the pointer, because a toast that disappears while
// you are reading it is worse than one that never appeared.
export default class extends Controller {
  static values = { after: Number }

  connect() {
    this.arm()
  }

  disconnect() {
    this.clear()
  }

  arm() {
    if (!this.hasAfterValue || this.afterValue <= 0) return
    this.clear()
    this.timer = setTimeout(() => this.dismiss(), this.afterValue)
  }

  hold() {
    this.clear()
  }

  clear() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
  }

  // Removal is on a timer rather than on transitionend. The first version
  // waited for the event and the message never left: the class landed, the
  // transition did not report finishing, and the card sat there permanently.
  // A leaving animation that fails should still leave.
  dismiss() {
    this.clear()

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.remove()
      return
    }

    this.element.classList.add("flash-leaving")
    setTimeout(() => this.element.remove(), LEAVE_MS)
  }
}
