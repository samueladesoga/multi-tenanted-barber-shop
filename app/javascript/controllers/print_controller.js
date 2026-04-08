import { Controller } from "@hotwired/stimulus"

// Triggers window.print() — attach to a button or auto-fire on connect.
//
// Auto-print on page load:
//   data-controller="print" data-print-auto-value="true"
//
// Manual button:
//   <button data-action="print#now">Print</button>
export default class extends Controller {
  static values = { auto: Boolean }

  connect() {
    if (this.autoValue) window.print()
  }

  now() {
    window.print()
  }
}
