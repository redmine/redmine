import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  #spaces = 2

  run(event) {
    const format = event.params.textFormatting
    if (format !== 'common_mark') return

    const input = event.currentTarget
    const { selectionStart, selectionEnd, value } = input
    const hasSelection = selectionStart !== selectionEnd
    if (!hasSelection) return
    const start = value.lastIndexOf("\n", selectionStart - 1) + 1
    const adjustedSelectionEnd = value[selectionEnd - 1] === "\n" ? selectionEnd - 1 : selectionEnd
    const end = value.indexOf("\n", adjustedSelectionEnd)
    const endPos = end === -1 ? value.length : end
    const selectedText = value.slice(start, endPos)
    const lines = selectedText.split("\n")

    event.preventDefault()

    const newLines = event.shiftKey
      ? lines.map(line => this.#unindentLine(line))
      : lines.map(line => this.#indentLine(line))

    const newText = newLines.join("\n")

    input.setRangeText(newText, start, endPos, "preserve")
    input.setSelectionRange(
      Math.max(start, selectionStart + newLines[0].length - lines[0].length),
      selectionEnd + newText.length - selectedText.length
    )
  }

  #indentLine(line) {
    return " ".repeat(this.#spaces) + line
  }

  #unindentLine(line) {
    const currentIndent = line.match(/^( *)/)[1].length
    const remove = Math.min(this.#spaces, currentIndent)
    return line.slice(remove)
  }
}
