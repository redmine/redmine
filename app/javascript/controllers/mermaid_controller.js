/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */
import { Controller } from "@hotwired/stimulus"

let mermaidInitialized = false;
let mermaidLoadPromise = null;

// Mermaid.js is not bundled with Redmine; administrators install it with
// `bin/rails redmine:mermaid:install`. When it is available, javascript_heads
// exposes its URL as window.MermaidAssetUrl. It is several MB, so it is only
// fetched (as a classic <script>) once a Mermaid code block actually needs
// rendering.
function loadMermaid() {
  if (typeof mermaid !== 'undefined') return Promise.resolve(mermaid);
  if (mermaidLoadPromise) return mermaidLoadPromise;

  const loading = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = window.MermaidAssetUrl;
    script.onload = () => {
      if (window.mermaid) {
        resolve(window.mermaid);
      } else {
        script.remove();
        reject(new Error('Mermaid.js loaded but window.mermaid is not defined'));
      }
    };
    script.onerror = () => {
      script.remove();
      reject(new Error('Failed to load Mermaid.js'));
    };
    document.head.appendChild(script);
  });
  // Keeping a rejected promise around would stop every later connect() in the
  // same page -- another block, or a repeated preview -- from trying again.
  loading.catch(() => {
    if (mermaidLoadPromise === loading) mermaidLoadPromise = null;
  });
  mermaidLoadPromise = loading;
  return loading;
}

// Connects to data-controller="mermaid"
// Renders Mermaid code blocks (marked with this controller by
// Redmine::WikiFormatting::SyntaxHighlight#process) as diagrams.
export default class extends Controller {
  connect() {
    // Mermaid.js is not installed: leave the code block as it is.
    if (!window.MermaidAssetUrl && typeof mermaid === 'undefined') return;

    loadMermaid().then((mermaid) => {
      // The block may have left the DOM while Mermaid.js was loading.
      if (this.element.isConnected) this.render(mermaid);
    }).catch((error) => {
      console.error('Failed to load Mermaid.js:', error);
    });
  }

  disconnect() {
    // Undo everything render() added so that a reconnect starts clean.
    this.container?.remove();
    this.container = null;
    const pre = this.element.closest('pre');
    if (pre) pre.style.display = '';
  }

  render(mermaid) {
    const pre = this.element.closest('pre');
    if (!pre) return;

    if (!mermaidInitialized) {
      mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });
      mermaidInitialized = true;
    }

    const container = document.createElement('div');
    container.className = 'mermaid';
    container.textContent = this.element.textContent.trim();
    pre.insertAdjacentElement('afterend', container);
    this.container = container;

    // Mermaid.js draws its own error diagram on failure, so the code block is
    // replaced either way. The rejection is left for the browser to report.
    mermaid.run({ nodes: [container], suppressErrors: false }).finally(() => {
      pre.style.display = 'none';
    });
  }
}
