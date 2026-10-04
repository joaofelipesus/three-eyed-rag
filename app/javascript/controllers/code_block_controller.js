import { Controller } from "@hotwired/stimulus"

// Copies a rendered code block's text to the clipboard and briefly shows a "Copied" state
export default class extends Controller {
  static targets = ["code", "button"]

  async copy() {
    await navigator.clipboard.writeText(this.codeTarget.textContent)
    this._showCopied()
  }

  disconnect() {
    clearTimeout(this.resetTimeout)
  }

  _showCopied() {
    this._toggleCopied(true)
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => this._toggleCopied(false), 2000)
  }

  _toggleCopied(copied) {
    this.buttonTarget.querySelector(".code-block-copy-idle").hidden = copied
    this.buttonTarget.querySelector(".code-block-copy-done").hidden = !copied
    this.buttonTarget.setAttribute("aria-label", copied ? "Copied" : "Copy code")
  }
}
