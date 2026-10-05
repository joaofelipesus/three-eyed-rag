import { Controller } from "@hotwired/stimulus"

// A trigger character at the start of the input or after a space, followed by the query typed so
// far up to the caret; spaces included, since names often have several words ("#rails decimal")
const TRIGGER_QUERY = /(^|\s)([#@])([^#@]*)$/

// "#" searches notes by file name and "@" searches tags; picking one adds it as a context chip
// whose hidden note_ids[] / tag_ids[] input chat_controller sends along with the message.
export default class extends Controller {
  static targets = ["input", "suggestions", "option", "context", "chips", "noteChipTemplate", "tagChipTemplate"]
  static values = { notesUrl: String, tagsUrl: String, limit: Number }

  disconnect() {
    clearTimeout(this.searchTimeout)
  }

  search() {
    // a dismissed trigger that has since been deleted shouldn't keep a new one at the same spot quiet
    if (!this._match()) this.dismissedTriggerIndex = null

    const trigger = this._trigger()
    clearTimeout(this.searchTimeout)
    if (!trigger) return this.close()

    this.searchTimeout = setTimeout(() => this._fetchSuggestions(trigger), 150)
  }

  navigate(event) {
    if (this.suggestionsTarget.hidden) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this._activate(this.activeIndex + 1)
        break
      case "ArrowUp":
        event.preventDefault()
        this._activate(this.activeIndex - 1)
        break
      case "Enter":
      case "Tab":
        if (this.optionTargets.length === 0) return
        event.preventDefault() // keeps Enter from submitting the question
        this._add(this.optionTargets[this.activeIndex])
        break
      case "Escape":
        event.preventDefault()
        this._dismiss()
        break
    }
  }

  pick(event) {
    this._add(event.currentTarget)
  }

  // clicking a suggestion shouldn't blur the input, which would close the list before the click lands
  keepFocus(event) {
    event.preventDefault()
  }

  remove(event) {
    event.currentTarget.closest(".context-chip").remove()
    this._toggleContext()
    this.inputTarget.focus()
  }

  close() {
    this.suggestionsTarget.hidden = true
    this.suggestionsTarget.innerHTML = ""
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  // Esc stops this trigger from searching, so the rest of the message can be typed after it
  _dismiss() {
    this.dismissedTriggerIndex = this._triggerIndex()
    this.close()
  }

  async _fetchSuggestions({ kind, query }) {
    const url = new URL(kind === "note" ? this.notesUrlValue : this.tagsUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    this._selectedIds(kind).forEach((id) => url.searchParams.append("exclude[]", id))

    const response = await fetch(url, { headers: { Accept: "text/html" } })
    // the user may have kept typing while this request was in flight
    const current = this._trigger()
    if (!response.ok || current?.kind !== kind || current?.query !== query) return

    this.suggestionsTarget.innerHTML = await response.text()
    this.suggestionsTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
    this._activate(0)
  }

  _add(option) {
    const { kind, id, label } = option.dataset

    if (!this._selectedIds(kind).includes(id) && this._selectedIds(kind).length < this.limitValue) {
      const template = kind === "note" ? this.noteChipTemplateTarget : this.tagChipTemplateTarget
      const chip = template.content.firstElementChild.cloneNode(true)
      chip.querySelector("input").value = id
      chip.querySelector(".context-chip-title").textContent = label
      const removeButton = chip.querySelector("button")
      removeButton.setAttribute("aria-label", `Remove ${label} from context`)
      removeButton.title = `Remove ${label} from context`
      this.chipsTarget.append(chip)
    }

    this._removeQueryFromInput()
    this.dismissedTriggerIndex = null
    this.close()
    this._toggleContext()
    this.inputTarget.focus()
  }

  _removeQueryFromInput() {
    const input = this.inputTarget
    const caret = input.selectionStart
    const before = input.value.slice(0, caret).replace(TRIGGER_QUERY, "$1")

    input.value = before + input.value.slice(caret)
    input.setSelectionRange(before.length, before.length)
  }

  _activate(index) {
    const options = this.optionTargets
    if (options.length === 0) return

    this.activeIndex = (index + options.length) % options.length
    options.forEach((option, i) => option.setAttribute("aria-selected", i === this.activeIndex ? "true" : "false"))
    this.inputTarget.setAttribute("aria-activedescendant", options[this.activeIndex].id)
    options[this.activeIndex].scrollIntoView({ block: "nearest" })
  }

  // the trigger being typed, as { kind: "note" | "tag", query }, or null
  _trigger() {
    const match = this._match()
    if (!match || this._triggerIndex() === this.dismissedTriggerIndex) return null

    return { kind: match[2] === "#" ? "note" : "tag", query: match[3] }
  }

  _match() {
    const input = this.inputTarget
    return input.value.slice(0, input.selectionStart).match(TRIGGER_QUERY)
  }

  // position of the trigger character that started the current query
  _triggerIndex() {
    const match = this._match()
    return match ? match.index + match[1].length : null
  }

  _selectedIds(kind) {
    return [...this.chipsTarget.querySelectorAll(`input[name='${kind}_ids[]']`)].map((input) => input.value)
  }

  _toggleContext() {
    this.contextTarget.hidden = this.chipsTarget.children.length === 0
  }
}
