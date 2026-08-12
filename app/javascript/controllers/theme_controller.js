import { Controller } from "@hotwired/stimulus"

// The two-state theme override: flips data-theme and persists the choice;
// the layout's head script re-applies it before first paint. Untoggled users keep
// following their OS preference via daisyUI's `--prefersdark` theme flag.
export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    const stored = localStorage.getItem("theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    this.checkboxTarget.checked = stored ? stored === "dark" : prefersDark
  }

  toggle() {
    const theme = this.checkboxTarget.checked ? "dark" : "light"
    localStorage.setItem("theme", theme)
    document.documentElement.setAttribute("data-theme", theme)
  }
}
