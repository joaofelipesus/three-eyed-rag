import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "input"]
  static values = { open: Boolean }

  connect() {
    this.openValue ? this._showForm() : this._showDisplay()
  }

  edit() {
    this._showForm()
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.inputTarget.value = this.inputTarget.defaultValue
    this._showDisplay()
  }

  _showForm() {
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
  }

  _showDisplay() {
    this.formTarget.hidden = true
    this.displayTarget.hidden = false
  }
}
