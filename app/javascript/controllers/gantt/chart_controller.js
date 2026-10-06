import { Controller } from "@hotwired/stimulus"

const RELATION_STROKE_WIDTH = 2
const SVG_NS = "http://www.w3.org/2000/svg"

export default class extends Controller {
  static targets = ["relations", "selectedColumn", "today"]

  static values = {
    issueRelationTypes: Object,
    showSelectedColumns: Boolean,
    showRelations: Boolean,
    showProgress: Boolean
  }

  #drawTop = 0
  #drawRight = 0
  #drawPaper = null
  #drawPaperGroup = null

  initialize() {
    this.$ = window.jQuery
  }

  connect() {
    this.#drawTop = 0
    this.#drawRight = 0

    this.#drawProgressLineAndRelations()
    this.#drawSelectedColumns()
  }

  disconnect() {
    if (this.#drawPaper) {
      this.#drawPaper.remove()
      this.#drawPaper = null
      this.#drawPaperGroup = null
    }
  }

  showSelectedColumnsValueChanged() {
    this.#drawSelectedColumns()
  }

  showRelationsValueChanged() {
    this.#drawProgressLineAndRelations()
  }

  showProgressValueChanged() {
    this.#drawProgressLineAndRelations()
  }

  handleWindowResize() {
    this.#drawProgressLineAndRelations()
    this.#drawSelectedColumns()
  }

  handleSubjectTreeChanged() {
    this.#drawProgressLineAndRelations()
    this.#drawSelectedColumns()
  }

  handleOptionsDisplay(event) {
    this.showSelectedColumnsValue = !!(event.detail && event.detail.enabled)
  }

  handleOptionsRelations(event) {
    this.showRelationsValue = !!(event.detail && event.detail.enabled)
  }

  handleOptionsProgress(event) {
    this.showProgressValue = !!(event.detail && event.detail.enabled)
  }

  #drawProgressLineAndRelations() {
    this.#setupDrawArea()
    this.#setupDrawPaper()
    this.#drawPaperGroup?.replaceChildren(); // Clear previous drawings

    if (this.showProgressValue) {
      this.#drawGanttProgressLines()
    }

    if (this.showRelationsValue) {
      this.#drawRelations()
    }

  }

  #setupDrawPaper() {
    const width = Math.ceil(this.$(this.relationsTarget).width() || 0)
    const height = Math.ceil(this.$(this.relationsTarget).height() || 0)

    if (!this.#drawPaper) {
      this.#drawPaper = document.createElementNS(SVG_NS, "svg")
      this.#drawPaper.setAttribute("aria-hidden", "true")
      this.#drawPaper.style.position = "absolute"
      this.#drawPaper.style.inset = "0"
      this.#drawPaper.style.pointerEvents = "none"

      this.#drawPaperGroup = document.createElementNS(SVG_NS, "g")
      this.#drawPaper.appendChild(this.#drawPaperGroup)
      this.relationsTarget.appendChild(this.#drawPaper)
    }

    const safeWidth = Math.max(width, 1)
    const safeHeight = Math.max(height, 1)
    this.#drawPaper.setAttribute("width", String(safeWidth))
    this.#drawPaper.setAttribute("height", String(safeHeight))
    this.#drawPaper.setAttribute("viewBox", `0 0 ${safeWidth} ${safeHeight}`)
  }

  #drawPath(pathData, attributes = {}) {
    if (!this.#drawPaperGroup) return

    const path = document.createElementNS(SVG_NS, "path")
    path.setAttribute("d", pathData.map((item) => String(item)).join(" "))

    Object.entries(attributes).forEach(([name, value]) => {
      path.setAttribute(name, String(value))
    })

    this.#drawPaperGroup.appendChild(path)
  }

  #setupDrawArea() {
    const $drawArea = this.$(this.relationsTarget)

    this.#drawTop = $drawArea.position().top
    this.#drawRight = $drawArea.width()
  }

  #drawSelectedColumns() {
    const isMobileDevice = typeof window.isMobile === "function" && window.isMobile()

    if (this.showSelectedColumnsValue) {
      if (isMobileDevice) {
        this.selectedColumnTargets.forEach((element) => { element.hidden = true })
      } else {
        this.selectedColumnTargets.forEach((element) => { element.hidden = false })
      }
    } else {
      this.selectedColumnTargets.forEach((element) => { element.hidden = true })
    }
  }

  get #relationsArray() {
    const relations = []

    this.$(".gantt-task-todo[data-gantt-relations]").each((_, element) => {
      const $element = this.$(element)

      if (!$element.is(":visible")) return

      const issueId = element.dataset.ganttIssueId
      const dataRels = JSON.parse(element.dataset.ganttRelations || "{}")

      Object.keys(dataRels).forEach((relTypeKey) => {
        this.$.each(dataRels[relTypeKey], (_, relatedIssue) => {
          relations.push({ issue_from: issueId, issue_to: relatedIssue, rel_type: relTypeKey })
        })
      })
    })

    return relations
  }

  #drawRelations() {
    const relations = this.#relationsArray

    relations.forEach((relation) => {
      const issueFrom = this.$(`.gantt-task-todo[data-gantt-issue-id='${relation.issue_from}']`)
      const issueTo = this.$(`.gantt-task-todo[data-gantt-issue-id='${relation.issue_to}']`)

      if (issueFrom.length === 0 || issueTo.length === 0) return
      if (!issueTo.is(":visible")) return

      const issueHeight = issueFrom.height()
      const issueFromTop = this.#taskTop(issueFrom) + issueHeight / 2 - this.#drawTop
      const issueFromRight = issueFrom.position().left + issueFrom.width()
      const issueToTop = this.#taskTop(issueTo) + issueHeight / 2 - this.#drawTop
      const issueToLeft = issueTo.position().left
      const relationConfig = this.issueRelationTypesValue[relation.rel_type] || {}
      const color = relationConfig.color || "#000"
      const landscapeMargin = relationConfig.landscape_margin || 0
      const issueFromRightRel = issueFromRight + landscapeMargin
      const issueToLeftRel = issueToLeft - landscapeMargin

      this.#drawPath(
        [
          "M",
          issueFromRight,
          issueFromTop,
          "L",
          issueFromRightRel,
          issueFromTop
        ],
        { stroke: color, "stroke-width": RELATION_STROKE_WIDTH, fill: "none" }
      )

      if (issueFromRightRel < issueToLeftRel) {
        this.#drawPath(
          [
            "M",
            issueFromRightRel,
            issueFromTop,
            "L",
            issueFromRightRel,
            issueToTop
          ],
          { stroke: color, "stroke-width": RELATION_STROKE_WIDTH, fill: "none" }
        )
        this.#drawPath(
          [
            "M",
            issueFromRightRel,
            issueToTop,
            "L",
            issueToLeft,
            issueToTop
          ],
          { stroke: color, "stroke-width": RELATION_STROKE_WIDTH, fill: "none" }
        )
      } else {
        const issueMiddleTop = issueToTop + issueHeight * (issueFromTop > issueToTop ? 1 : -1)
        this.#drawPath(
          [
            "M",
            issueFromRightRel,
            issueFromTop,
            "L",
            issueFromRightRel,
            issueMiddleTop
          ],
          { stroke: color, "stroke-width": RELATION_STROKE_WIDTH, fill: "none" }
        )
        this.#drawPath(
          [
            "M",
            issueFromRightRel,
            issueMiddleTop,
            "L",
            issueToLeftRel,
            issueMiddleTop
          ],
          { stroke: color, "stroke-width": RELATION_STROKE_WIDTH, fill: "none" }
        )
        this.#drawPath(
          [
            "M",
            issueToLeftRel,
            issueMiddleTop,
            "L",
            issueToLeftRel,
            issueToTop
          ],
          { stroke: color, "stroke-width": RELATION_STROKE_WIDTH, fill: "none" }
        )
        this.#drawPath(
          [
            "M",
            issueToLeftRel,
            issueToTop,
            "L",
            issueToLeft,
            issueToTop
          ],
          { stroke: color, "stroke-width": RELATION_STROKE_WIDTH, fill: "none" }
        )
      }
      this.#drawPath(
        [
          "M",
          issueToLeft,
          issueToTop,
          "l",
          -4 * RELATION_STROKE_WIDTH,
          -2 * RELATION_STROKE_WIDTH,
          "l",
          0,
          4 * RELATION_STROKE_WIDTH,
          "z"
        ],
        {
          stroke: "none",
          fill: color
        }
      )
    })
  }

  #taskTop($task) {
    const row = $task.closest(".gantt-row")
    return row.position().top + $task.position().top
  }

  get #progressLinesArray() {
    const lines = []
    const todayLeft = this.$(this.todayTarget).position().left

    lines.push({ left: todayLeft, top: 0 })

    this.$("[data-gantt-column='subjects'] .gantt-row[data-gantt-row-type='issue'], [data-gantt-column='subjects'] .gantt-row[data-gantt-row-type='version']").each((_, element) => {
      const $element = this.$(element)

      if (!$element.is(":visible")) return true

      const topPosition = $element.position().top - this.#drawTop
      const elementHeight = $element.height() / 9
      const elementTopUpper = topPosition - elementHeight
      const elementTopCenter = topPosition + elementHeight * 3
      const elementTopLower = topPosition + elementHeight * 8
      const issueClosed = $element.children("span").hasClass("issue-closed")
      const versionClosed = $element.children("span").hasClass("version-closed")

      if (issueClosed || versionClosed) {
        lines.push({ left: todayLeft, top: elementTopCenter })
      } else {
        const rowKey = element.dataset.ganttRowKey
        const issueDone = this.$(`.gantt-row[data-gantt-row-key='${rowKey}'] .gantt-task-done`)
        const isBehindStart = $element.children("span").hasClass("behind-start-date")
        const isOverEnd = $element.children("span").hasClass("over-end-date")

        if (isOverEnd) {
          lines.push({ left: this.#drawRight, top: elementTopUpper, is_right_edge: true })
          lines.push({
            left: this.#drawRight,
            top: elementTopLower,
            is_right_edge: true,
            none_stroke: true
          })
        } else if (issueDone.length > 0) {
          const doneLeft = issueDone.first().position().left + issueDone.first().width()
          lines.push({ left: doneLeft, top: elementTopCenter })
        } else if (isBehindStart) {
          lines.push({ left: 0, top: elementTopUpper, is_left_edge: true })
          lines.push({
            left: 0,
            top: elementTopLower,
            is_left_edge: true,
            none_stroke: true
          })
        } else {
          let todoLeft = todayLeft
          const issueTodo = this.$(`.gantt-row[data-gantt-row-key='${rowKey}'] .gantt-task-todo`)
          if (issueTodo.length > 0) {
            todoLeft = issueTodo.first().position().left
          }
          lines.push({ left: Math.min(todayLeft, todoLeft), top: elementTopCenter })
        }
      }
    })

    return lines
  }

  #drawGanttProgressLines() {
    if (!this.hasTodayTarget) return

    const progressLines = this.#progressLinesArray
    const color = this.$(this.todayTarget).css("border-inline-start-color") || "#ff0000"

    for (let index = 1; index < progressLines.length; index += 1) {
      const current = progressLines[index]
      const previous = progressLines[index - 1]

      if (
        !current.none_stroke &&
        !(
          (previous.is_right_edge && current.is_right_edge) ||
          (previous.is_left_edge && current.is_left_edge)
        )
      ) {
        const x1 = previous.left
        const x2 = current.left

        this.#drawPath(["M", x1, previous.top, "L", x2, current.top], {
          stroke: color,
          "stroke-width": 2,
          fill: "none"
        })
      }
    }
  }

}
