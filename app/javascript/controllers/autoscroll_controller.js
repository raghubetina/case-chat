import { Controller } from "@hotwired/stimulus"

// Keeps the transcript pinned to the newest text while a reply streams in —
// but only if the reader is already at the bottom. Yanking someone back down
// while they are reading earlier answers is worse than not scrolling at all.
export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.pinned = true
    this.element.addEventListener("scroll", this.track)
    this.observer = new MutationObserver(() => this.scroll())
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true })
    this.scroll()
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.track)
    this.observer?.disconnect()
  }

  track = () => {
    const distance = this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight
    this.pinned = distance < 80
  }

  scroll() {
    if (this.pinned) this.element.scrollTop = this.element.scrollHeight
  }
}
