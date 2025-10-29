import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  initialize() {
    this.$ = window.jQuery
  }

  handleResizeColumn(event) {
    const columnWidth = event.detail.width;

    this.$(".issue-subject, .project-name, .version-name").each((_, element) => {
      const $element = this.$(element)
      $element.width(columnWidth - $element.position().left)
    })
  }

  handleEntryClick(event) {
    const iconExpander = event.currentTarget
    const $subject = this.$(iconExpander.parentElement)
    const subjectLeft =
      parseInt($subject.css("left"), 10) + parseInt(iconExpander.offsetWidth, 10)

    let targetShown = null
    let targetTop = 0
    let totalHeight = 0
    let outOfHierarchy = false

    const willOpen = !$subject.hasClass("open")

    this.#setIconState($subject, willOpen)

    $subject.nextAll("div").each((_, element) => {
      const $element = this.$(element)
      const json = $element.data("collapse-expand")
      const numberOfRows = $element.data("number-of-rows")
      const barsSelector = `#gantt_area form > div[data-collapse-expand='${json.obj_id}'][data-number-of-rows='${numberOfRows}']`
      const selectedColumnsSelector = `td.gantt_selected_column div[data-collapse-expand='${json.obj_id}'][data-number-of-rows='${numberOfRows}']`

      if (outOfHierarchy || parseInt($element.css("left"), 10) <= subjectLeft) {
        outOfHierarchy = true

        if (targetShown === null) return false

        const newTopVal = parseInt($element.css("top"), 10) + totalHeight * (targetShown ? -1 : 1)

        $element.css("top", newTopVal)
        this.$([barsSelector, selectedColumnsSelector].join()).each((__, el) => {
          this.$(el).css("top", newTopVal)
        })

        return true
      }

      const isShown = $element.is(":visible")

      if (targetShown === null) {
        targetShown = isShown
        targetTop = parseInt($element.css("top"), 10)
        totalHeight = 0
      }

      if (isShown === targetShown) {
        this.$(barsSelector).each((__, task) => {
          const $task = this.$(task)

          if (!isShown && willOpen) {
            $task.css("top", targetTop + totalHeight)
          }
          if (!$task.hasClass("tooltip")) {
            $task.toggle(willOpen)
          }
        })

        this.$(selectedColumnsSelector).each((__, attr) => {
          const $attr = this.$(attr)

          if (!isShown && willOpen) {
            $attr.css("top", targetTop + totalHeight)
          }
          $attr.toggle(willOpen)
        })

        if (!isShown && willOpen) {
          $element.css("top", targetTop + totalHeight)
        }

        this.#setIconState($element, willOpen)
        $element.toggle(willOpen)
        totalHeight += parseInt(json.top_increment, 10)
      }
    })

    this.dispatch("toggle-tree", { bubbles: true })
  }

  #setIconState(element, open) {
    const $element = element.jquery ? element : this.$(element)
    const expander = $element.find(".expander")

    if (open) {
      $element.addClass("open")

      if (expander.length > 0) {
        expander.removeClass("icon-collapsed").addClass("icon-expanded")

        if (expander.find("svg").length === 1) {
          window.updateSVGIcon(expander[0], "angle-down")
        }
      }
    } else {
      $element.removeClass("open")

      if (expander.length > 0) {
        expander.removeClass("icon-expanded").addClass("icon-collapsed")

        if (expander.find("svg").length === 1) {
          window.updateSVGIcon(expander[0], "angle-right")
        }
      }
    }
  }
}
