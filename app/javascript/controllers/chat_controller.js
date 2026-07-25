import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "messages", "form"]
  static values = { conversationId: String }

  connect() {
    // wait for the layout so the browser has a scroll height to animate towards
    requestAnimationFrame(() => this._scrollToBottom("smooth"))
  }

  async send(event) {
    event.preventDefault()

    // check min content size to make a request
    const content = this.inputTarget.value
    if (content.trim().length < 3) return

    // change content while submitting
    this.submitTarget.disabled = true
    this.submitTarget.value = "Sending..."
    this.inputTarget.value = ""

    const answerElement = this._appendMessage(content)

    try {
      await this._streamAnswer(content, answerElement)
    } finally {
      this.submitTarget.disabled = false
      this.submitTarget.value = "Send"
    }
  }

  // function that create a new message in the chat
  _appendMessage(content) {
    const message = document.createElement("div")
    message.classList.add("chat-message")

    const question = document.createElement("p")
    question.classList.add("chat-message-question")
    question.textContent = content

    const answer = document.createElement("div")
    answer.classList.add("chat-message-answer")

    message.append(question, answer)
    this.messagesTarget.append(message)
    this._scrollToBottom()

    return answer
  }

  // keep the last message visible
  _scrollToBottom(behavior = "auto") {
    this.messagesTarget.scrollTo({ top: this.messagesTarget.scrollHeight, behavior })
  }

  // handle streaming answer from the backend
  async _streamAnswer(content, answerElement) {
    const body = new URLSearchParams({ content }) // format params into a valid body format
    if (this.conversationIdValue) body.set("conversation_id", this.conversationIdValue)

    const response = await fetch(this.formTarget.action, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        Accept: "text/event-stream",
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body
    })

    // handle streaming content
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ""

    while (true) {
      const { value, done } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })

      let boundary
      while ((boundary = buffer.indexOf("\n\n")) !== -1) {
        this._processEvent(buffer.slice(0, boundary), answerElement)
        buffer = buffer.slice(boundary + 2)
        this._scrollToBottom()
      }
    }
  }

  // process each event from the streaming
  _processEvent(rawEvent, answerElement) {
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
      if (payload.conversation) {
        this._startConversation(payload.conversation)
      }
    } else if (payload.content) {
      answerElement.textContent += payload.content
    }
  }

  // create a new conversation in the sidebar
  _startConversation(conversation) {
    this.conversationIdValue = conversation.id
    window.history.replaceState({}, "", conversation.url)

    const sidebarList = document.getElementById("sidebar_conversations_list")
    if (!sidebarList) return

    const item = document.createElement("li")
    item.id = `conversation_${conversation.id}`
    const link = document.createElement("a")
    link.href = conversation.url
    link.textContent = conversation.title
    link.classList.add("sidebar-conversation-link")
    item.append(link)

    sidebarList.prepend(item)
    while (sidebarList.children.length > 5) sidebarList.lastElementChild.remove()
  }
}
