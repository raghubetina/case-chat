import { Controller } from "@hotwired/stimulus"

// Keeps the transcript pinned to the newest text while a reply streams in —
// but only if the reader is already at the bottom. Yanking someone back down
// while they are reading earlier answers is worse than not scrolling at all.
export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.pinned = true
    this.element.addEventListener("scroll", this.track)
    this.observer = new MutationObserver(() => this.schedule())
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true })
    this.schedule()
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.track)
    this.observer?.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  track = () => {
    // Ignore the scroll events our own scrolling emits, or a reader who has
    // moved up gets re-pinned by the next character that arrives.
    if (this.scrolling) return
    const distance = this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight
    this.pinned = distance < 80
  }

  // A streaming reply mutates the DOM many times a second, and each mutation
  // used to write scrollTop immediately. Writing it once per frame instead
  // keeps the scroll from fighting the layout it just triggered.
  schedule() {
    if (this.frame) return
    this.frame = requestAnimationFrame(() => {
      this.frame = null
      if (!this.pinned) return

      this.scrolling = true
      this.element.scrollTop = this.element.scrollHeight
      requestAnimationFrame(() => {
        this.scrolling = false
      })
    })
  }
}
