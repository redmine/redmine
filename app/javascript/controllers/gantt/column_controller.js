import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    minWidth: Number,
    // Local value
    mobileMode: { type: Boolean, default: false }
  }

  #$element = null

  initialize() {
    this.$ = window.jQuery
  }

  connect() {
    this.#$element = this.$(this.element)
    this.#setupResizable()
  }

  disconnect() {
    this.#$element?.resizable("destroy")
    this.#$element = null
  }

  handleWindowResize(_event) {
    this.mobileModeValue = this.#isMobile()
  }

  mobileModeValueChanged(current, old) {
    if (current == old) return

    if (this.mobileModeValue) {
      this.#$element?.resizable("disable")
    } else {
      this.#$element?.resizable("enable")
    }
  }

  #setupResizable() {
    const options = {
      handles: "e",
      minWidth: this.minWidthValue,
      zIndex: 30,
      resize: (_event, ui) => {
        this.element.style.setProperty("--gantt-column-width", `${ui.size.width}px`)
        this.element.style.removeProperty("width")
      }
    }

    this.#$element.resizable(options)
  }

  #isMobile() {
    return !!(typeof window.isMobile === "function" && window.isMobile())
  }
}
