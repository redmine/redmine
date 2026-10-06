import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  handleEntryClick(event) {
    const subject = event.currentTarget.closest(".gantt-row")
    if (!subject) return

    const chart = this.element.closest(".gantt-chart")
    const subjectRows = this.rowTargets
    const subjectKey = subject.dataset.ganttRowKey
    const descendantKeys = new Set([subjectKey])
    const descendants = []
    const willOpen = !subject.classList.contains("is-expanded")

    subjectRows.forEach((row) => {
      if (row === subject) return
      if (!descendantKeys.has(row.dataset.ganttParentRowKey)) return

      descendantKeys.add(row.dataset.ganttRowKey)
      descendants.push(row)
    })

    this.#setIconState(subject, willOpen)
    descendants.forEach((row) => {
      this.#setIconState(row, willOpen)
      chart.querySelectorAll(this.#rowSelector(row.dataset.ganttRowKey)).forEach((matchingRow) => {
        matchingRow.hidden = !willOpen
      })
    })

    this.#positionVisibleRows(chart, subjectRows)

    this.dispatch("toggle-tree", { bubbles: true })
  }

  #positionVisibleRows(chart, subjectRows) {
    const chartStyle = window.getComputedStyle(chart)
    const contentTop = parseFloat(chartStyle.getPropertyValue("--gantt-content-top")) || 0
    const rowHeight = parseFloat(window.getComputedStyle(subjectRows[0]).blockSize) || 20
    let top = contentTop

    subjectRows.forEach((row) => {
      if (row.hidden) return

      chart.querySelectorAll(this.#rowSelector(row.dataset.ganttRowKey)).forEach((matchingRow) => {
        matchingRow.style.setProperty("--gantt-row-top", `${top}px`)
      })
      top += rowHeight
    })
  }

  #rowSelector(rowKey) {
    return `.gantt-row[data-gantt-row-key="${CSS.escape(rowKey)}"]`
  }

  #setIconState(element, open) {
    const expander = element.querySelector(".expander")
    if (!expander) return

    element.classList.toggle("is-expanded", open)
    expander.classList.toggle("icon-expanded", open)
    expander.classList.toggle("icon-collapsed", !open)
    if (expander.querySelectorAll("svg").length === 1) {
      window.updateSVGIcon(expander, open ? "angle-down" : "angle-right")
    }
  }
}
