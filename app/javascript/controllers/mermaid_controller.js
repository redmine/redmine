/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */
import { Controller } from "@hotwired/stimulus"

// Diagrams are saved larger than their original size so that they stay sharp when enlarged.
const PNG_SCALE = 2;
// Larger diagrams are scaled down so that saving them does not use up memory.
const MAX_PNG_PIXELS_PER_SIDE = 4096;
const MAX_PNG_TOTAL_PIXELS = 8_000_000;

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
      // Show the source that the mermaid-available CSS rule hides.
      this.element.closest('pre')?.classList.add('mermaid-failed');
    });
  }

  disconnect() {
    // Undo everything render() added so that a reconnect starts clean.
    this.container?.remove();
    this.errorElement?.remove();
    this.downloadLink?.remove();
    this.container = this.errorElement = this.downloadLink = null;
    const pre = this.element.closest('pre');
    if (pre) {
      pre.style.display = '';
      pre.classList.remove('mermaid-failed');
    }
  }

  render(mermaid) {
    const pre = this.element.closest('pre');
    if (!pre) return;

    if (!mermaidInitialized) {
      mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', suppressErrorRendering: true });
      mermaidInitialized = true;
    }

    const container = document.createElement('div');
    container.className = 'mermaid';
    container.textContent = this.element.textContent.trim();
    // Keep the source text in the container from flashing until Mermaid.js
    // replaces it with the diagram. Mermaid.js measures the diagram inside
    // the container, so it is made invisible rather than display: none, and
    // taken out of the flow so that only the hidden <pre> reserves space.
    container.style.visibility = 'hidden';
    container.style.position = 'absolute';
    container.style.insetInline = '0';
    pre.insertAdjacentElement('afterend', container);
    this.container = container;

    // On failure, show a Redmine flash message while keeping the source block
    // visible, so that the invalid diagram can be inspected and copied.
    mermaid.run({ nodes: [container], suppressErrors: false }).then(() => {
      pre.style.display = 'none';
      container.style.visibility = container.style.position = container.style.insetInline = '';
      if (this.container === container) this.addDownloadLink(pre, container);
    }).catch((error) => {
      container.remove();
      if (this.container === container) this.container = null;
      pre.classList.add('mermaid-failed');

      const errorElement = document.createElement('div');
      errorElement.className = 'flash error';
      errorElement.innerHTML = '<p>Failed to render mermaid diagram:</p>';

      const message = document.createElement('p');
      message.textContent = error?.message || String(error);
      errorElement.appendChild(message);

      // CopypreScrubber wraps the <pre> in div.pre-wrapper; put the message above the whole block.
      const anchor = pre.closest('.pre-wrapper') || pre;
      anchor.insertAdjacentElement('beforebegin', errorElement);
      this.errorElement = errorElement;
    });
  }

  addDownloadLink(pre, container) {
    const link = document.createElement('a');
    link.className = 'mermaid-download-link icon-only';
    link.title = rm.I18n.buttonDownload;
    // A link without href cannot be operated with the keyboard.
    link.href = '#';
    link.append(createSVGIcon('download'));
    link.addEventListener('click', (event) => {
      event.preventDefault();
      this.download();
    });

    // Put the link next to the copy button that CopypreScrubber adds to div.pre-wrapper.
    const wrapper = pre.closest('.pre-wrapper');
    if (wrapper) {
      wrapper.append(link);
    } else {
      container.insertAdjacentElement('beforebegin', link);
    }
    this.downloadLink = link;
  }

  // The diagram is saved as a PNG image because the SVG generated by Mermaid.js
  // relies on HTML and CSS and is not displayed properly outside web browsers.
  async download() {
    try {
      const svg = this.container.querySelector('svg');
      const scale = this.pngScaleFor(svg);
      const canvas = await this.drawOnCanvas(svg, scale);
      canvas.toBlob((png) => {
        if (png) this.saveAs(png, this.filenameFor(svg, scale));
      }, 'image/png');
    } catch (error) {
      console.error('Failed to save Mermaid diagram:', error);
    }
  }

  pngScaleFor(svg) {
    const { width, height } = svg.viewBox.baseVal;
    return Math.min(
      PNG_SCALE,
      MAX_PNG_PIXELS_PER_SIDE / Math.max(width, height),
      Math.sqrt(MAX_PNG_TOTAL_PIXELS / (width * height))
    );
  }

  // Returns a name like mermaid-flowchart@2x.png, or mermaid-flowchart.png
  // when the image has been scaled down.
  filenameFor(svg, scale) {
    // Mermaid.js sets the diagram type here, such as "sequence" or "flowchart-v2".
    const diagramType = (svg.getAttribute('aria-roledescription') || '').replace(/-v\d+$/, '');
    const name = /^[a-z0-9]+$/i.test(diagramType) ? diagramType : 'diagram';
    const suffix = scale === PNG_SCALE ? `@${PNG_SCALE}x` : '';
    return `mermaid-${name}${suffix}.png`;
  }

  async drawOnCanvas(svg, scale) {
    const { width, height } = svg.viewBox.baseVal;
    // Rounded down so that the limits are never exceeded.
    const pngWidth = Math.floor(width * scale);
    const pngHeight = Math.floor(height * scale);

    // Unlike cloneNode(), this copy does not fetch <img> elements in labels again.
    const standaloneSvg = document.implementation.createHTMLDocument('').importNode(svg, true);
    // Gives the SVG the size of the PNG so that it is rendered at that size from
    // the start, without the max-width that Mermaid.js sets to the original width.
    standaloneSvg.setAttribute('width', pngWidth);
    standaloneSvg.setAttribute('height', pngHeight);
    standaloneSvg.style.removeProperty('max-width');
    const source = new XMLSerializer().serializeToString(standaloneSvg);

    const image = new Image();
    // Not a blob: URL, with which Chrome refuses to export a canvas once an
    // SVG containing <foreignObject> has been drawn on it.
    image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(source);
    await image.decode();

    const canvas = document.createElement('canvas');
    canvas.width = pngWidth;
    canvas.height = pngHeight;
    canvas.getContext('2d').drawImage(image, 0, 0);
    return canvas;
  }

  saveAs(blob, filename) {
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    link.click();
    // Give the browser time to start the download before releasing the blob.
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
  }
}
