import { Controller } from "@hotwired/stimulus"

const COLUMN_WIDTH_STORE_KEY = "redmine-gantt-column-width"

class ColumnWidthStore {
  constructor(key) {
    this.key = key
  }

  get(column) {
    const width = this.#read()[column]
    return Number.isFinite(width) ? width : null
  }

  set(column, width) {
    if (!Number.isFinite(width)) return

    const widths = this.#read()
    widths[column] = width
    this.#write(widths)
  }

  #read() {
    try {
      const value = window.localStorage.getItem(this.key)
      if (value === null) return {}

      const widths = JSON.parse(value)
      if (!widths || typeof widths !== "object" || Array.isArray(widths)) {
        return {}
      }

      return widths
    } catch (_error) {
      return {}
    }
  }

  #write(widths) {
    try {
      window.localStorage.setItem(this.key, JSON.stringify(widths))
    } catch (_error) {}
  }
}

export default class extends Controller {
  static targets = ["handle"]

  static values = {
    minWidth: Number,
    // Local value
    mobileMode: { type: Boolean, default: false }
  }

  #$element = null
  #columnWidthStore = null

  initialize() {
    this.$ = window.jQuery
  }

  connect() {
    this.#$element = this.$(this.element)
    this.#columnWidthStore = new ColumnWidthStore(COLUMN_WIDTH_STORE_KEY)
    this.mobileModeValue = this.#isMobile()

    this.#restoreWidth()
    this.#setupResizable()
  }

  disconnect() {
    this.#$element?.resizable("destroy")
    this.#$element = null
    this.#columnWidthStore = null
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

  get #columnName() {
    return this.element.dataset.ganttColumn
  }

  fitWidth() {
    const extraPadding = 10
    let width = 0

    // Temporarily apply this class to measure the content width needed to fit the column.
    this.element.classList.add("gantt-column-measuring")
    try {
      this.element.querySelectorAll(".gantt-pane > header, .gantt-row:not([hidden])").forEach((content) => {
        width = Math.max(width, content.getBoundingClientRect().width)
      })
    } finally {
      this.element.classList.remove("gantt-column-measuring")
    }

    width = Math.max(this.minWidthValue, Math.ceil(width) + extraPadding)
    this.dispatch("resize-start")
    this.#setWidth(width)
    this.#saveWidth(width)
  }

  #setupResizable() {
    const options = {
      handles: { e: this.handleTarget },
      minWidth: this.minWidthValue,
      disabled: this.mobileModeValue,
      start: () => {
        this.dispatch("resize-start")
      },
      resize: (_event, ui) => {
        this.#setWidth(ui.size.width)
      },
      stop: (_event, ui) => {
        if (ui.originalSize.width !== ui.size.width) {
          this.#saveWidth(ui.size.width)
        }
      }
    }

    this.#$element.resizable(options)
  }

  #setWidth(width) {
    this.element.style.setProperty("--gantt-column-width", `${width}px`)
    this.element.style.removeProperty("width")
    this.dispatch("resize", { detail: { width } })
  }

  #restoreWidth() {
    const width = this.#columnWidthStore.get(this.#columnName)

    if (width !== null && width >= this.minWidthValue) {
      this.element.style.setProperty("--gantt-column-width", `${width}px`)
    }

    this.data.set("width-restored", "")
  }

  #saveWidth(width) {
    if (width < this.minWidthValue) return

    this.#columnWidthStore.set(this.#columnName, width)
  }

  #isMobile() {
    return !!(typeof window.isMobile === "function" && window.isMobile())
  }
}
