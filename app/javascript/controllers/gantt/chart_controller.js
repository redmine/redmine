import { Controller } from "@hotwired/stimulus"

const RELATION_STROKE_WIDTH = 2

export default class extends Controller {
  static targets = ["ganttArea", "drawArea", "subjectsContainer"]

  static values = {
    issueRelationTypes: Object,
    showSelectedColumns: Boolean,
    showRelations: Boolean,
    showProgress: Boolean
  }

  #drawTop = 0
  #drawRight = 0
  #drawLeft = 0
  #drawPaper = null

  initialize() {
    this.$ = window.jQuery
    this.Raphael = window.Raphael
  }

  connect() {
    this.#drawTop = 0
    this.#drawRight = 0
    this.#drawLeft = 0

    this.#drawProgressLineAndRelations()
    this.#drawSelectedColumns()
  }

  disconnect() {
    if (this.#drawPaper) {
      this.#drawPaper.remove()
      this.#drawPaper = null
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
    if (this.#drawPaper) {
      this.#drawPaper.clear()
    } else {
      this.#drawPaper = this.Raphael(this.drawAreaTarget)
    }

    this.#setupDrawArea()

    if (this.showProgressValue) {
      this.#drawGanttProgressLines()
    }

    if (this.showRelationsValue) {
      this.#drawRelations()
    }

  }

  #setupDrawArea() {
    const $drawArea = this.$(this.drawAreaTarget)
    const $ganttArea = this.hasGanttAreaTarget ? this.$(this.ganttAreaTarget) : null

    this.#drawTop = $drawArea.position().top
    this.#drawRight = $drawArea.width()
    this.#drawLeft = $ganttArea ? $ganttArea.scrollLeft() : 0
  }

  #drawSelectedColumns() {
    const $selectedColumns = this.$("td.gantt_selected_column")
    const $subjectsContainer = this.$(".gantt_subjects_container")

    const isMobileDevice = typeof window.isMobile === "function" && window.isMobile()

    if (this.showSelectedColumnsValue) {
      if (isMobileDevice) {
        $selectedColumns.each((_, element) => {
          this.$(element).hide()
        })
      } else {
        $subjectsContainer.addClass("draw_selected_columns")
        $selectedColumns.show()
      }
    } else {
      $selectedColumns.each((_, element) => {
        this.$(element).hide()
      })
      $subjectsContainer.removeClass("draw_selected_columns")
    }
  }

  get #relationsArray() {
    const relations = []

    this.$("div.task_todo[data-rels]").each((_, element) => {
      const $element = this.$(element)

      if (!$element.is(":visible")) return

      const elementId = $element.attr("id")

      if (!elementId) return

      const issueId = elementId.replace("task-todo-issue-", "")
      const dataRels = $element.data("rels") || {}

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
      const issueFrom = this.$(`#task-todo-issue-${relation.issue_from}`)
      const issueTo = this.$(`#task-todo-issue-${relation.issue_to}`)

      if (issueFrom.length === 0 || issueTo.length === 0) return

      const issueHeight = issueFrom.height()
      const issueFromTop = issueFrom.position().top + issueHeight / 2 - this.#drawTop
      const issueFromRight = issueFrom.position().left + issueFrom.width()
      const issueToTop = issueTo.position().top + issueHeight / 2 - this.#drawTop
      const issueToLeft = issueTo.position().left
      const relationConfig = this.issueRelationTypesValue[relation.rel_type] || {}
      const color = relationConfig.color || "#000"
      const landscapeMargin = relationConfig.landscape_margin || 0
      const issueFromRightRel = issueFromRight + landscapeMargin
      const issueToLeftRel = issueToLeft - landscapeMargin

      this.#drawPaper
        .path([
          "M",
          issueFromRight + this.#drawLeft,
          issueFromTop,
          "L",
          issueFromRightRel + this.#drawLeft,
          issueFromTop
        ])
        .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })

      if (issueFromRightRel < issueToLeftRel) {
        this.#drawPaper
          .path([
            "M",
            issueFromRightRel + this.#drawLeft,
            issueFromTop,
            "L",
            issueFromRightRel + this.#drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.#drawPaper
          .path([
            "M",
            issueFromRightRel + this.#drawLeft,
            issueToTop,
            "L",
            issueToLeft + this.#drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
      } else {
        const issueMiddleTop = issueToTop + issueHeight * (issueFromTop > issueToTop ? 1 : -1)
        this.#drawPaper
          .path([
            "M",
            issueFromRightRel + this.#drawLeft,
            issueFromTop,
            "L",
            issueFromRightRel + this.#drawLeft,
            issueMiddleTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.#drawPaper
          .path([
            "M",
            issueFromRightRel + this.#drawLeft,
            issueMiddleTop,
            "L",
            issueToLeftRel + this.#drawLeft,
            issueMiddleTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.#drawPaper
          .path([
            "M",
            issueToLeftRel + this.#drawLeft,
            issueMiddleTop,
            "L",
            issueToLeftRel + this.#drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.#drawPaper
          .path([
            "M",
            issueToLeftRel + this.#drawLeft,
            issueToTop,
            "L",
            issueToLeft + this.#drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
      }
      this.#drawPaper
        .path([
          "M",
          issueToLeft + this.#drawLeft,
          issueToTop,
          "l",
          -4 * RELATION_STROKE_WIDTH,
          -2 * RELATION_STROKE_WIDTH,
          "l",
          0,
          4 * RELATION_STROKE_WIDTH,
          "z"
        ])
        .attr({
          stroke: "none",
          fill: color,
          "stroke-linecap": "butt",
          "stroke-linejoin": "miter"
        })
    })
  }

  get #progressLinesArray() {
    const lines = []
    const todayLeft = this.$("#today_line").position().left

    lines.push({ left: todayLeft, top: 0 })

    this.$("div.issue-subject, div.version-name").each((_, element) => {
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
        const issueDone = this.$(`#task-done-${$element.attr("id")}`)
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
          const issueTodo = this.$(`#task-todo-${$element.attr("id")}`)
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
    if (this.$("#today_line").length === 0) return

    const progressLines = this.#progressLinesArray
    const color = this.$("#today_line").css("border-inline-start-color") || "#ff0000"

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
        const x1 = previous.left === 0 ? 0 : previous.left + this.#drawLeft
        const x2 = current.left === 0 ? 0 : current.left + this.#drawLeft

        this.#drawPaper
          .path(["M", x1, previous.top, "L", x2, current.top])
          .attr({ stroke: color, "stroke-width": 2 })
      }
    }
  }
}
