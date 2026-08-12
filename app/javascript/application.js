// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

document.addEventListener("turbo:load", () => {
  document.documentElement.removeAttribute("data-turbo-not-loaded")
  document.documentElement.removeAttribute("data-turbo-loading")
})

document.addEventListener("turbo:submit-start", (event) => {
  if (!(event.target instanceof Element)) return
  if (event.target.closest("turbo-frame")) return

  document.documentElement.setAttribute("data-turbo-loading", "true")
})

document.addEventListener("turbo:submit-end", (event) => {
  if (!event.detail.fetchResponse?.redirected) {
    document.documentElement.removeAttribute("data-turbo-loading")
  }
})
