import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.closeBinding = this.close.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.contentTarget.classList.toggle("hidden")

    if (!this.contentTarget.classList.contains("hidden")) {
      document.addEventListener("click", this.closeBinding)
      document.addEventListener("keydown", this.closeBinding)
    } else {
      document.removeEventListener("click", this.closeBinding)
      document.removeEventListener("keydown", this.closeBinding)
    }
  }

  close(event) {
    if (event.type === "keydown" && event.key !== "Escape") {
      return
    }

    if (event.type === "click" && this.element.contains(event.target)) {
      return
    }

    this.contentTarget.classList.add("hidden")
    document.removeEventListener("click", this.closeBinding)
    document.removeEventListener("keydown", this.closeBinding)
  }

  disconnect() {
    document.removeEventListener("click", this.closeBinding)
    document.removeEventListener("keydown", this.closeBinding)
  }
}
