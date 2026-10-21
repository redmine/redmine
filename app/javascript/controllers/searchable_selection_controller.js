/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */

import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

export default class extends Controller {
  static targets = ["input", "list", "hiddenContainer"]
  static values = {
    url: String,
    checkboxSelector: String,
    checkboxName: String,
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    this.selectedValues = new Set()
    this.isLoadingMore = false
    this.debounceTimer = null
    this.searchAbortController = null

    // Track any checkboxes that are checked initially or stored in hidden inputs
    if (this.hasHiddenContainerTarget) {
      this.hiddenContainerTarget.querySelectorAll('input[type="hidden"]').forEach(input => {
        this.selectedValues.add(input.value)
      })
    }
    if (this.hasListTarget) {
      this.listTarget.querySelectorAll(`${this.checkboxSelector}:checked`).forEach(cb => {
        this.selectedValues.add(cb.value)
      })
    }
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    if (this.searchAbortController) {
      this.searchAbortController.abort()
    }
  }

  get checkboxName() {
    if (this.hasCheckboxNameValue && this.checkboxNameValue) {
      return this.checkboxNameValue
    }
    const firstCheckbox = this.hasListTarget ? this.listTarget.querySelector('input[type="checkbox"]') : null
    return firstCheckbox ? firstCheckbox.name : ""
  }

  get checkboxSelector() {
    return this.hasCheckboxSelectorValue && this.checkboxSelectorValue
      ? this.checkboxSelectorValue
      : (this.checkboxName ? `input[name="${this.checkboxName}"]` : 'input[type="checkbox"]')
  }

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.performSearch()
    }, this.debounceDelayValue)
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      clearTimeout(this.debounceTimer)
      this.performSearch()
    }
  }

  performSearch() {
    const q = this.hasInputTarget ? this.inputTarget.value.trim() : ""
    this.fetchResults({ q }, { append: false })
  }

  async loadMore(event) {
    event.preventDefault()
    if (this.isLoadingMore) return

    const trigger = event.currentTarget.closest('[data-role="load-more"]')
    const url = new URL(event.currentTarget.href, window.location.origin)
    const offset = url.searchParams.get("offset")
    const q = this.hasInputTarget ? this.inputTarget.value.trim() : ""

    await this.fetchResults({ q, offset }, { append: true, trigger })
  }

  toggle(event) {
    const checkbox = event.target
    if (!checkbox.matches(this.checkboxSelector)) return

    if (checkbox.checked) {
      this.selectedValues.add(checkbox.value)
    } else {
      this.selectedValues.delete(checkbox.value)
    }
    this.syncHiddenInputs()
  }

  async fetchResults(params, { append = false, trigger = null } = {}) {
    if (append) {
      if (this.isLoadingMore) return
      this.isLoadingMore = true
    } else {
      if (this.searchAbortController) {
        this.searchAbortController.abort()
      }
      this.searchAbortController = new AbortController()
    }

    const targetElement = trigger || (this.hasInputTarget ? this.inputTarget : this.element)
    targetElement.classList.add("ajax-loading")

    try {
      const url = new URL(this.urlValue, window.location.origin)
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== "") {
          url.searchParams.set(key, value)
        }
      })

      const signal = append ? null : this.searchAbortController.signal
      const response = await get(url.toString(), { responseKind: "html", signal })
      if (!response.ok) return

      const html = await response.html

      if (append && trigger) {
        trigger.insertAdjacentHTML("beforebegin", html)
        const nextTrigger = this.hasListTarget ? this.listTarget.querySelector('[data-role="load-more"] a') : null
        trigger.remove()
        if (nextTrigger) nextTrigger.focus()
      } else if (this.hasListTarget) {
        this.listTarget.innerHTML = html
      }

      this.syncCheckboxes()
      this.syncHiddenInputs()
    } catch (error) {
      if (error.name === "AbortError") return
      throw error
    } finally {
      if (append) {
        this.isLoadingMore = false
      }
      if (targetElement.isConnected) {
        targetElement.classList.remove("ajax-loading")
      }
    }
  }

  syncCheckboxes() {
    if (!this.hasListTarget) return
    this.listTarget.querySelectorAll(this.checkboxSelector).forEach(cb => {
      cb.checked = this.selectedValues.has(cb.value)
    })
  }

  syncHiddenInputs() {
    if (!this.hasHiddenContainerTarget) return

    const name = this.checkboxName
    if (!name) return

    this.hiddenContainerTarget.innerHTML = ""
    this.selectedValues.forEach(val => {
      const escaped = typeof CSS !== "undefined" && CSS.escape ? CSS.escape(val) : val
      if (!this.hasListTarget || !this.listTarget.querySelector(`${this.checkboxSelector}[value="${escaped}"]`)) {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = name
        input.value = val
        this.hiddenContainerTarget.appendChild(input)
      }
    })
  }
}
