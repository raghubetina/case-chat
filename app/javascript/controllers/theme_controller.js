import { Controller } from "@hotwired/stimulus"

const THEMES = ["ledger", "bureau", "dusk", "chicago"]

// The theme picker: sets data-theme and persists the choice; the layout's head
// script re-applies it before first paint. "auto" clears the override so the
// OS preference rules again (chicago by default, dusk via `prefersdark`).
export default class extends Controller {
  static targets = ["option"]

  connect() {
    this.reflect()
  }

  set(event) {
    const name = event.params.name
    if (THEMES.includes(name)) {
      localStorage.setItem("theme", name)
      document.documentElement.setAttribute("data-theme", name)
    } else {
      localStorage.removeItem("theme")
      document.documentElement.removeAttribute("data-theme")
    }
    this.reflect()
    document.activeElement?.blur() // dropdown is :focus-within-driven; close it
  }

  reflect() {
    const stored = localStorage.getItem("theme")
    for (const option of this.optionTargets) {
      const name = option.dataset.themeNameParam
      const active = stored ? name === stored : name === "auto"
      option.setAttribute("aria-checked", active ? "true" : "false")
    }
  }
}
