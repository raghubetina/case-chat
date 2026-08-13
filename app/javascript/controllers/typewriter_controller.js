import { Controller } from "@hotwired/stimulus"

// Decouples how fast a reply *arrives* from how fast it *appears*.
//
// Measured against the real API: text arrives as a handful of frames of
// 110-200 characters, roughly 700ms apart. Rendering those directly is what
// made a live reply land in three visible slabs. Nothing upstream is
// coalescing them — raw SSE shows the same cadence — so the only place to fix
// it is here, by buffering arrivals and revealing them at a steady rate.
//
// Turbo appends deltas into the hidden buffer; this drains that buffer into
// the visible node a few characters per frame.
export default class extends Controller {
  static targets = ["shown", "buffer"]

  // Whatever is queued is revealed over this long, so a burst that arrives at
  // once still reads as typing while never falling far behind the model.
  static DRAIN_MS = 250

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.observer = new MutationObserver(() => this.schedule())
    this.observer.observe(this.bufferTarget, { childList: true, characterData: true, subtree: true })
    this.schedule()
  }

  disconnect() {
    this.observer?.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  schedule() {
    if (this.frame) return
    this.frame = requestAnimationFrame(() => this.tick())
  }

  tick() {
    this.frame = null
    const queued = this.bufferTarget.textContent
    if (!queued) return

    // Someone who has asked for less motion wants the text, not the effect.
    const take = this.reduced
      ? queued.length
      : Math.max(1, Math.ceil(queued.length / (this.constructor.DRAIN_MS / 16.7)))

    this.shownTarget.append(queued.slice(0, take))
    this.bufferTarget.textContent = queued.slice(take)

    if (this.bufferTarget.textContent) this.schedule()
  }
}
