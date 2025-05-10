import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["original", "stickyHeader"];

  connect() {
    if (!this.originalTarget || !this.stickyHeaderTarget) return;

    this.observer = new IntersectionObserver(
      ([entry]) => {
        this.stickyHeaderTarget.classList.toggle("is-visible", !entry.isIntersecting);
      },
      { threshold: 0 }
    );

    this.observer.observe(this.originalTarget);
  }

  disconnect() {
    this.observer?.disconnect();
  }
}
