import { Controller } from "@hotwired/stimulus"

// The composer: grows with its content, clears after a successful send, and
// treats Enter as send (Shift+Enter for a newline), which is what every chat
// interface has trained people to expect.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.grow()
  }

  grow() {
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = `${el.scrollHeight}px`
  }

  submitOnEnter(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    if (this.inputTarget.value.trim()) this.element.requestSubmit()
  }

  clear(event) {
    if (!event.detail?.success) return
    this.inputTarget.value = ""
    this.grow()
    this.inputTarget.focus()
  }
}
