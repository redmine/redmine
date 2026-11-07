import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { initials: String, class: String };

  connect() {
    // The image may have failed to load before the controller was connected
    const failedToLoad = this.element.complete && this.element.naturalWidth === 0;
    if (failedToLoad) this.replace();
  }

  replace() {
    const span = document.createElement("span");
    span.setAttribute("role", "img");
    span.className = this.classValue;
    span.textContent = this.initialsValue;
    if (this.element.title) span.title = this.element.title;

    this.element.replaceWith(span);
  }
}
