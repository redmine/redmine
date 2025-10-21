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
  // Example: '  * text'  → indent='  ', bullet='*', content='text' (or '+' or '-')
  #bulletItemPattern  = /^(?<indent>\s*)(?<bullet>[*+\-]) (?<content>.*)$/;
  // Example: '  1. text' → indent='  ', num='1', delimiter='.', content='text' (or ')')
  #orderedItemPattern = /^(?<indent>\s*)(?<num>\d+)(?<delimiter>[.)]) (?<content>.*)$/;
  // Example: '[ ] Task'  → taskContent='Task'
  //          '[x] Task'  → taskContent='Task'
  #taskAtStartPattern = /^\[[ x]\] (?<taskContent>.*)$/;

  format(line) {
    const bulletMatch = line.match(this.#bulletItemPattern);
    if (bulletMatch) {
      return (
        this.#formatBulletTask(bulletMatch.groups) ||
        this.#formatBulletList(bulletMatch.groups)
      );
    }

    const orderedMatch = line.match(this.#orderedItemPattern);
    if (orderedMatch) {
      return (
        this.#formatOrderedTask(orderedMatch.groups) ||
        this.#formatOrderedList(orderedMatch.groups)
      );
    }
  }

  // '- [ ] Task' or '* [ ] Task' or '+ [ ] Task'
  #formatBulletTask({ indent, bullet, content }) {
    const m = content.match(this.#taskAtStartPattern);
    if (!m) return null;
    const taskContent = m.groups.taskContent;

    return taskContent === ''
      ? { action: 'remove' }
      : { action: 'insert', text: `${indent}${bullet} [ ] ` };
  }

  // '- Item' or '* Item' or '+ Item'
  #formatBulletList({ indent, bullet, content }) {
    return content === ''
      ? { action: 'remove' }
      : { action: 'insert', text: `${indent}${bullet} ` };
  }

  // '1. [ ] Task' or '1) [ ] Task'
  #formatOrderedTask({ indent, num, delimiter, content }) {
    const m = content.match(this.#taskAtStartPattern);
    if (!m) return null;
    const taskContent = m.groups.taskContent;

    const next = `${Number(num) + 1}${delimiter}`;
    return taskContent === ''
      ? { action: 'remove' }
      : { action: 'insert', text: `${indent}${next} [ ] ` };
  }

  // '1. Item' or '1) Item'
  #formatOrderedList({ indent, num, delimiter, content }) {
    const next = `${Number(num) + 1}${delimiter}`;
    return content === ''
      ? { action: 'remove' }
      : { action: 'insert', text: `${indent}${next} ` };
  }
}

class TextileListFormatter {
  format(line) {
    // Examples:
    // '# ordered text'            → marker='#',  content='ordered text'
    // '## nested ordered text'    → marker='##', content='nested ordered text'
    // '* unordered text'          → marker='*',  content='unordered text'
    // '** nested unordered text'  → marker='**', content='nested unordered text'
    const match = line.match(/^(?<marker>[*#]+) (?<content>.*)$/);
    if (!match) return null

    const { marker, content } = match.groups;
    return content === ''
      ? { action: 'remove' }
      : { action: 'insert', text: `${marker} ` };
  }
}

export default class extends Controller {
  handleBeforeInput(event) {
    if (event.inputType != 'insertLineBreak') return

    const format = event.params.textFormatting
    new ListAutofillHandler(event.currentTarget, format).run(event)
  }
}
