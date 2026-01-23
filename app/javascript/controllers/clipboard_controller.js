/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ['pre'];

  copyPre(e) {
    e.preventDefault();
    const element = e.currentTarget;
    let textToCopy = (this.preTarget.querySelector("code") || this.preTarget).textContent.replace(/\n$/, '');
    if (this.preTarget.querySelector("code.syntaxhl")) { textToCopy = textToCopy.replace(/ $/, ''); } // Workaround for half-width space issue in Textile's highlighted code

    this.copy(textToCopy).then(() => {
      updateSVGIcon(element, "checked");
      setTimeout(() => updateSVGIcon(element, "copy-pre-content"), 2000);
    });
  }

  copyText(e) {
    e.preventDefault();
    this.copy(e.currentTarget.dataset.clipboardText);

    const element = e.currentTarget.closest('.drdn.expanded');
    if (element !== null) {
      element.classList.remove('expanded');
    }
  }

  copy(text) {
    if (navigator.clipboard) {
      return navigator.clipboard.writeText(text).catch(() => {
        return this.fallback(text);
      });
    } else {
      return this.fallback(text);
    }
  }

  fallback(text) {
    const temp = document.createElement('textarea');
    temp.value = text;
    temp.style.position = 'fixed';
    temp.style.left = '-9999px';
    document.body.appendChild(temp);
    temp.select();
    document.execCommand('copy');
    document.body.removeChild(temp);
    return Promise.resolve();
  }
}
