import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "mode",
    "fixedDate",
    "fixedDateInput",
    "dateOffset",
    "dateOffsetInput"
  ]

  connect() {
    this.update()
  }

  update() {
    const mode = this.modeTarget.value

    this.fixedDateTarget.hidden = mode !== "fixed_date"
    this.fixedDateInputTarget.disabled = mode !== "fixed_date"
    this.dateOffsetTarget.hidden = mode !== "date_offset"
    this.dateOffsetInputTarget.disabled = mode !== "date_offset"
  }
}
