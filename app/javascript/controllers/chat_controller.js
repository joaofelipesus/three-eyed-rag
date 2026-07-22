import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  start() {
    this.submitTarget.disabled = true
    this.submitTarget.value = "Sending..."
  }

  end() {
    this.submitTarget.disabled = false
    this.submitTarget.value = "Send"
    this.inputTarget.value = ""
  }
}
