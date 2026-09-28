import { Controller } from '@hotwired/stimulus'

class CommonMarkTableFormatter {
  format(rows) {
    const output = []
    output.push(this.#formatRow(rows[0]))

    const separator = rows[0].map(() => '--').join(' | ')
    output.push(`| ${separator} |`)

    for (let i = 1; i < rows.length; i++) {
      output.push(this.#formatRow(rows[i]))
    }

    return output.join('\n')
  }

  #formatRow(row) {
    return `| ${row.map(cell => this.#formatCell(cell)).join(' | ')} |`
  }

  #formatCell(cell) {
    return cell
      .replaceAll('|', '\\|')
      .replaceAll('\n', '<br>')
  }
}

class TextileTableFormatter {
  format(rows) {
    const output = []
    output.push(this.#formatHeader(rows[0]))

    for (let i = 1; i < rows.length; i++) {
      output.push(this.#formatRow(rows[i]))
    }

    return output.join('\n')
  }

  #formatHeader(row) {
    return `|_. ${row.map(cell => this.#formatCell(cell)).join(' |_. ')} |`
  }

  #formatRow(row) {
    return `| ${row.map(cell => this.#formatCell(cell)).join(' | ')} |`
  }

  #formatCell(cell) {
    return cell.replaceAll('|', '&#124;')
  }
}

export default class extends Controller {
  handlePaste(event) {
    const formatter = this.#tableFormatterFor(event.params.textFormatting)
    if (!formatter) return

    const html = this.#htmlFromClipboard(event)
    if (!html) return

    // Extract the table only when the pasted HTML consists of a single table.
    const table = this.#extractTable(html)
    if (!table) return

    const tableData = this.#buildTableData(table)
    if (!tableData) return

    const formattedTable = formatter.format(tableData)
    if (!formattedTable) return

    event.preventDefault()
    this.#insertTextAtCursor(event.currentTarget, formattedTable)
  }

  // private

  #tableFormatterFor(textFormatting) {
    switch (textFormatting) {
      case 'common_mark':
        return new CommonMarkTableFormatter()
      case 'textile':
        return new TextileTableFormatter()
      default:
        return null
    }
  }

  #htmlFromClipboard(event) {
    const clipboardData = event.clipboardData
    if (!clipboardData) return null

    return clipboardData.getData('text/html') || null
  }

  #extractTable(html) {
    const doc = new DOMParser().parseFromString(html.replace(/\r?\n/g, ''), 'text/html')
    if (!doc.body) return null

    const tables = doc.body.querySelectorAll('table')
    if (tables.length !== 1) return null

    const clone = doc.body.cloneNode(true)
    // Ignore metadata elements and confirm that nothing remains outside the table.
    clone.querySelectorAll('meta, style, link, title, table').forEach(element => element.remove())

    return clone.textContent.trim() === '' ? tables[0] : null
  }

  #buildTableData(table) {
    const rows = []
    table.querySelectorAll('tr').forEach(tr => {
      const cells = []
      tr.querySelectorAll('td, th').forEach(cell => {
        cells.push(this.#extractCellText(cell).trim())
      })
      if (cells.length > 0) {
        rows.push(cells)
      }
    })

    if (rows.length < 2) return null

    const maxColumns = rows.reduce((currentMax, row) => Math.max(currentMax, row.length), 0)
    if (maxColumns < 2) return null

    rows.forEach(row => {
      while (row.length < maxColumns) {
        row.push('')
      }
    })

    return rows
  }

  #extractCellText(cell) {
    const clone = cell.cloneNode(true)

    // Treat <br> as an in-cell line break and keep it as an internal newline
    // so each formatter can render it appropriately.
    clone.querySelectorAll('br').forEach(br => {
      br.replaceWith('\n')
    })

    return clone.textContent
  }

  #insertTextAtCursor(input, text) {
    const { selectionStart, selectionEnd } = input

    const replacement = `${text}\n\n`

    input.setRangeText(replacement, selectionStart, selectionEnd, 'end')
    const newCursorPos = selectionStart + replacement.length
    input.setSelectionRange(newCursorPos, newCursorPos)

    input.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
