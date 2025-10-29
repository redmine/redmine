import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    minWidth: Number,
    column: String,
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
    this.#dispatchResizeColumn()
  }

  disconnect() {
    this.#$element?.resizable("destroy")
    this.#$element = null
  }

  handleWindowResize(_event) {
    this.mobileModeValue = this.#isMobile()

    this.#dispatchResizeColumn()
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
    const alsoResize = [
      `.gantt_${this.columnValue}_container`,
      `.gantt_${this.columnValue}_container > .gantt_hdr`
    ]
    const options = {
      handles: "e",
      minWidth: this.minWidthValue,
      zIndex: 30,
      alsoResize: alsoResize.join(","),
      create: () => {
        this.$(".ui-resizable-e").css("cursor", "ew-resize")
      }
    }

    this.#$element
      .resizable(options)
      .on("resize", (event) => {
        event.stopPropagation()
        this.#dispatchResizeColumn()
      })
  }

  #dispatchResizeColumn() {
    if (!this.#$element) return

    this.dispatch(`resize-column-${this.columnValue}`, { detail: { width: this.#$element.width() } })
  }

  #isMobile() {
    return !!(typeof window.isMobile === "function" && window.isMobile())
  }
}
