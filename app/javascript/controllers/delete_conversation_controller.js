import { Controller } from "@hotwired/stimulus"

// Opens a modal asking the user to type a confirmation phrase before deleting a conversation
export default class extends Controller {
  static targets = ["dialog", "input", "submit"]
  static values = { confirmation: String }

  open() {
    this.inputTarget.value = ""
    this.check()
    this.dialogTarget.showModal()
    this.inputTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  // clicks on the dialog element itself land on its backdrop, outside the panel
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  check() {
    this.submitTarget.disabled = this.inputTarget.value !== this.confirmationValue
  }
}
