import { Controller } from '@hotwired/stimulus'

class ListAutofillHandler {
  constructor(inputElement, format) {
    this.input = inputElement
    this.format = format
  }

  run(event) {
    const { selectionStart, value } = this.input

    const beforeCursor = value.slice(0, selectionStart)
    const lines = beforeCursor.split("\n")
    const currentLine = lines[lines.length - 1]
    const lineStartPos = beforeCursor.lastIndexOf("\n") + 1

    let formatter
    switch (this.format) {
      case 'common_mark':
        formatter = new CommonMarkListFormatter()
        break
      case 'textile':
        formatter = new TextileListFormatter()
        break
      default:
        return
    }

    const result = formatter.format(currentLine)

    if (!result) return

    switch (result.action) {
      case 'remove':
        event.preventDefault()
        this.input.setRangeText('', lineStartPos, selectionStart, 'start')
        break
      case 'insert':
        event.preventDefault()
        const insertText = "\n" + result.text
        const newValue = value.slice(0, selectionStart) + insertText + value.slice(selectionStart)
        const newCursor = selectionStart + insertText.length
        this.input.value = newValue
        this.input.setSelectionRange(newCursor, newCursor)
        break
      default:
        return
    }
  }
}

class CommonMarkListFormatter {
  format(line) {
    // Match list items in CommonMark syntax.
    // Captures either an ordered list (e.g., '1. ' or '2) ') or an unordered list (e.g., '* ', '- ', '+ ').
    // The regex structure:
    // ^(\s*)               → leading whitespace
    // (?:(\d+)([.)])       → an ordered list marker: number followed by '.' or ')'
    // |([*+\-])            → OR an unordered list marker: '*', '+', or '-'
    // (.*)$                → the actual list item content
    //
    // Examples:
    // '2. ordered text'           → indent='',  number='2', delimiter='.', bullet=undefined, content='ordered text'
    // '  3) nested ordered text'  → indent='  ', number='3', delimiter=')', bullet=undefined, content='nested ordered text'
    // '* unordered text'          → indent='', number=undefined, delimiter=undefined, bullet='*', content='unordered text'
    // '+ unordered text'          → indent='', number=undefined, delimiter=undefined, bullet='+', content='unordered text'
    // '  - nested unordered text' → indent='  ', number=undefined, delimiter=undefined, bullet='-', content='nested unordered text'
    const match = line.match(/^(\s*)(?:(\d+)([.)])|([*+\-])) (.*)$/)
    if (!match) return null

    const indent = match[1]
    const number = match[2]
    const delimiter = match[3]
    const bullet = match[4]
    const content = match[5]

    if (content === '') {
      return { action: 'remove' }
    }

    if (number) {
      const nextNumber = parseInt(number, 10) + 1
      return { action: 'insert', text: `${indent}${nextNumber}${delimiter} ` }
    } else {
      return { action: 'insert', text: `${indent}${bullet} ` }
    }
  }
}

class TextileListFormatter {
  format(line) {
    // Match list items in Textile syntax.
    // Captures either an ordered list (using '#') or an unordered list (using '*').
    // The regex structure:
    // ^([*#]+)            → one or more list markers: '*' for unordered, '#' for ordered
    // (.*)$               → the actual list item content
    //
    // Examples:
    // '# ordered text'            → marker='#',  content='ordered text'
    // '## nested ordered text'    → marker='##', content='nested ordered text'
    // '* unordered text'          → marker='*',  content='unordered text'
    // '** nested unordered text'  → marker='**', content='nested unordered text'
    const match = line.match(/^([*#]+) (.*)$/)
    if (!match) return null

    const marker = match[1]
    const content = match[2]

    if (content === '') {
      return { action: 'remove' }
    }

    return { action: 'insert', text: `${marker} ` }
  }
}

export default class extends Controller {
  handleBeforeInput(event) {
    if (event.inputType != 'insertLineBreak') return

    const format = event.params.textFormatting
    new ListAutofillHandler(event.currentTarget, format).run(event)
  }
}
