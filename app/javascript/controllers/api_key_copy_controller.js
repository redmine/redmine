import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["apiKey"];

  copy(event) {
    event.preventDefault();

    const apiKeyText = this.apiKeyTarget.textContent?.trim();
    if (!apiKeyText) return;

    const svgIcon = event.target.closest('.copy-api-key-link').querySelector('svg')
    if (!svgIcon) return;

    copyToClipboard(apiKeyText).then(() => {
      updateSVGIcon(svgIcon, 'checked');
      setTimeout(() => {
        updateSVGIcon(svgIcon, 'copy');
      }, 2000);
    });
  }
}