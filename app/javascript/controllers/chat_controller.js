import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "messages", "form"]

  async send(event) {
    event.preventDefault()

    const query = this.inputTarget.value
    if (query.trim().length < 3) return

    this.submitTarget.disabled = true
    this.submitTarget.value = "Sending..."
    this.inputTarget.value = ""

    const answerElement = this.appendMessage(query)

    try {
      await this.streamAnswer(query, answerElement)
    } finally {
      this.submitTarget.disabled = false
      this.submitTarget.value = "Send"
    }
  }

  appendMessage(query) {
    const message = document.createElement("div")
    message.classList.add("chat-message")

    const question = document.createElement("p")
    question.classList.add("chat-message-question")
    question.textContent = query

    const answer = document.createElement("div")
    answer.classList.add("chat-message-answer")

    message.append(question, answer)
    this.messagesTarget.append(message)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight

    return answer
  }

  async streamAnswer(query, answerElement) {
    const response = await fetch(this.formTarget.action, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        Accept: "text/event-stream",
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({ query })
    })

    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ""

    while (true) {
      const { value, done } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })

      let boundary
      while ((boundary = buffer.indexOf("\n\n")) !== -1) {
        this.processEvent(buffer.slice(0, boundary), answerElement)
        buffer = buffer.slice(boundary + 2)
        this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
      }
    }
  }

  processEvent(rawEvent, answerElement) {
    let eventName = "chunk"
    let data = null

    rawEvent.split("\n").forEach((line) => {
      if (line.startsWith("event:")) eventName = line.slice(6).trim()
      if (line.startsWith("data:")) data = line.slice(5).trim()
    })

    if (!data) return
    const payload = JSON.parse(data)

    if (eventName === "done") {
      answerElement.innerHTML = payload.html
    } else if (payload.content) {
      answerElement.textContent += payload.content
    }
  }
}
