import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  // Shows the history tab if the target note is hidden by the selected tab,
  // so that the browser can jump to the note
  show() {
    const note = document.getElementById(this.element.hash.slice(1));
    if (!note || note.getClientRects().length > 0) return;

    const historyTab = document.getElementById("tab-history");
    if (!historyTab) return;

    showIssueHistory("history", historyTab.href);
  }
}
