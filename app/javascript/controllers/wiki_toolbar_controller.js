/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */
import { Controller } from '@hotwired/stimulus'

const isMac = /mac|iphone|ipad/i.test(navigator.userAgentData?.platform || navigator.platform)

// Wiki toolbar rendered by Redmine::WikiToolbar.
//
// The toolbar is rendered after the textarea and moves itself to the
// textarea's position on connect, so that existing views only need to call
// wikitoolbar_for. The text formatting syntax is given by the button
// parameters, so this controller is shared by all text formatters.
export default class extends Controller {
  static targets = ['editor', 'preview', 'editTab', 'previewTab', 'toolbar', 'precodeMenu', 'tableMenu']
  static values = {
    fieldId: String,
    previewUrl: String,
    helpUrl: String
  }

  // Editor whose preview was displayed last, switched back to edit mode
  // using the Ctrl/Cmd+Shift+P shortcut from outside of the textareas
  static lastPreviewed = null

  connect() {
    this.field = document.getElementById(this.fieldIdValue)
    if (!this.field) return

    if (!this.editorTarget.contains(this.field)) {
      // Moving the element reconnects the controller
      this.field.before(this.element)
      this.editorTarget.prepend(this.field)
    }
    this.addShortcutsToTitles()
    this.element.hidden = false
  }

  disconnect() {
    this.closeMenu()
    if (this.constructor.lastPreviewed === this) this.constructor.lastPreviewed = null
  }

  // Actions

  wrap({ params: { prefix, suffix } }) {
    this.encloseSelection(String(prefix), String(suffix ?? prefix))
  }

  wrapLines({ params: { prefix = '', suffix = '', strip, pattern, replacement = '' } }) {
    this.encloseLineSelection(String(prefix), String(suffix), (str) => {
      if (strip) {
        str = str.replace(new RegExp(strip), '')
      }
      if (pattern) {
        str = str.replace(/\r/g, '').replace(new RegExp(`(\\n|^)${pattern}`, 'g'), `$1${replacement}`)
      }
      return str
    })
  }

  help() {
    window.open(this.helpUrlValue, '', 'resizable=yes, location=no, width=300, height=640, menubar=no, status=no, scrollbars=yes')
  }

  shortcut(event) {
    if (event.target !== this.field || !(isMac ? event.metaKey : event.ctrlKey)) return

    const button = this.toolbarTarget.querySelector(`[data-wiki-toolbar-shortcut="${event.key.toLowerCase()}"]`)
    if (button) {
      event.preventDefault()
      button.click()
    }
  }

  // Preview

  edit() {
    if (!this.previewing) return

    this.previewRequest = null
    this.previewTarget.classList.add('hidden')
    this.field.classList.remove('hidden')
    this.toolbarTarget.classList.remove('hidden')
    this.selectTab(this.editTabTarget, this.previewTabTarget)
    this.field.focus()
  }

  async preview() {
    if (this.previewing) return

    this.constructor.lastPreviewed = this
    this.previewTarget.style.minHeight = `${this.field.clientHeight}px`
    this.field.classList.add('hidden')
    this.toolbarTarget.classList.add('hidden')
    this.previewTarget.classList.remove('hidden')
    this.selectTab(this.previewTabTarget, this.editTabTarget)
    this.closeMenu()

    const request = this.previewRequest = this.fetchPreview()
    const html = await request
    if (request === this.previewRequest && html !== null) {
      this.previewTarget.innerHTML = html
    }
  }

  togglePreview(event) {
    if (event.target === this.field) {
      event.preventDefault()
      this.preview()
    } else if (this.constructor.lastPreviewed === this && !event.target.closest?.('.jstEditor')) {
      event.preventDefault()
      this.constructor.lastPreviewed = null
      this.edit()
    }
  }

  // Menus

  toggleMenu({ currentTarget, params }) {
    const opened = this.menu?.dataset.name === params.menu
    this.closeMenu()
    if (opened) return

    const template = this[`${params.menu}MenuTarget`]
    this.menu = template.content.firstElementChild.cloneNode(true)
    this.menu.dataset.name = params.menu
    this.menuParams = params
    this.element.append(this.menu)
    this.positionMenu(currentTarget)

    this.closeMenuOnOutsideClick = (event) => {
      if (!this.menu.contains(event.target) && !currentTarget.contains(event.target)) this.closeMenu()
    }
    document.addEventListener('mousedown', this.closeMenuOnOutsideClick)
    this.menu.querySelector('button')?.focus()
  }

  closeMenu() {
    if (!this.menu) return

    document.removeEventListener('mousedown', this.closeMenuOnOutsideClick)
    this.menu.remove()
    this.menu = null
    this.closeMenuOnOutsideClick = null
  }

  insertTable({ params: { cols, rows } }) {
    const { headerCell, separatorCell } = this.menuParams
    const names = 'ABCDEFGHIJ'.slice(0, cols).split('')
    const line = (cells) => `|${cells.join('|')}|\n`

    let table = line(names.map((name) => String(headerCell).replace('%{name}', name)))
    if (separatorCell) table += line(Array(cols).fill(separatorCell))
    table += line(Array(cols).fill('  ')).repeat(rows)
    this.encloseLineSelection(table, '')
  }

  highlightTable({ target }) {
    const button = target.closest('button')
    if (!button) return

    const { wikiToolbarColsParam: cols, wikiToolbarRowsParam: rows } = button.dataset
    this.menu.querySelectorAll('button').forEach((cell) => {
      const selected = Number(cell.dataset.wikiToolbarColsParam) <= Number(cols) &&
        Number(cell.dataset.wikiToolbarRowsParam) <= Number(rows)
      cell.parentElement.classList.toggle('selected-cell', selected)
    })
  }

  // Private

  get previewing() {
    return this.previewTabTarget.classList.contains('selected')
  }

  selectTab(selected, unselected) {
    selected.classList.add('selected')
    selected.setAttribute('aria-selected', 'true')
    unselected.classList.remove('selected')
    unselected.setAttribute('aria-selected', 'false')
  }

  async fetchPreview() {
    const body = new FormData()
    body.append('text', this.field.value)
    this.field.form?.querySelectorAll('.attachments_fields input, [data-preview-param]').forEach((input) => {
      if (input.name && input.value) body.append(input.name, input.value)
    })

    try {
      const response = await fetch(this.previewUrlValue, {
        method: 'POST',
        body: body,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      if (response.ok) return await response.text()
    } catch (error) {
      console.error('Preview failed', error)
    }
    return null
  }

  addShortcutsToTitles() {
    this.toolbarTarget.querySelectorAll('[data-wiki-toolbar-shortcut]').forEach((button) => {
      const key = button.dataset.wikiToolbarShortcut.toUpperCase()
      button.title = `${button.textContent} (${isMac ? '⌘' : 'Ctrl+'}${key})`
    })
  }

  positionMenu(button) {
    const parent = this.menu.offsetParent || document.documentElement
    const parentRect = parent.getBoundingClientRect()
    const buttonRect = button.getBoundingClientRect()
    this.menu.style.left = `${buttonRect.left - parentRect.left + parent.scrollLeft}px`
    this.menu.style.top = `${buttonRect.bottom - parentRect.top + parent.scrollTop}px`
  }

  encloseSelection(prefix, suffix) {
    const field = this.field
    field.focus()

    let start = field.selectionStart
    let end = field.selectionEnd
    let sel = field.value.substring(start, end)
    const scrollPos = field.scrollTop

    if (start > 0 && /\S/.test(field.value.charAt(start - 1))) prefix = ` ${prefix}`
    if (/\S/.test(field.value.charAt(end))) suffix = `${suffix} `
    if (sel.endsWith(' ')) {
      // exclude ending space char, if any
      sel = sel.slice(0, -1)
      suffix = `${suffix} `
    }

    const subst = prefix + sel + suffix
    const caret = sel ? start + subst.length : start + prefix.length
    this.replaceRange(subst, start, end, caret, scrollPos)
  }

  encloseLineSelection(prefix, suffix, fn) {
    const field = this.field
    field.focus()

    const value = field.value
    let start = field.selectionStart
    let end = field.selectionEnd
    const scrollPos = field.scrollTop
    const emptySelection = start === end

    // go to the start and the end of the lines
    start = value.substring(0, start).replace(/[^\r\n]*$/, '').length
    end = value.length - value.substring(end).replace(/^[^\r\n]*/, '').length

    let sel = value.substring(start, end)
    if (sel.endsWith(' ')) {
      // exclude ending space char, if any
      sel = sel.slice(0, -1)
      suffix = `${suffix} `
    }

    const res = fn ? fn(sel) : sel
    const subst = prefix + res + suffix
    const caret = (sel || (!prefix && emptySelection)) ? start + subst.length : start + prefix.length
    this.replaceRange(subst, start, end, caret, scrollPos)
  }

  replaceRange(text, start, end, caret, scrollPos) {
    this.field.setRangeText(text, start, end)
    this.field.setSelectionRange(caret, caret)
    this.field.scrollTop = scrollPos
    this.field.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
