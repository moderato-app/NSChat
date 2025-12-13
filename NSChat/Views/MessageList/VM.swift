import Combine
import os
import SwiftData
import SwiftUI
import Throttler

private var deltaTextCache: [String: String] = [:]
private var countTextCache: [String: Int] = [:]

extension InputAreaView {
  static let whiteSpaces: [Character] = ["\n", " ", "\t"]

  func setupDebounce() {
    cancellable?.cancel()
    cancellable = subject
      .debounce(for: .seconds(1), scheduler: RunLoop.main)
      .sink { value in
        AppLogger.ui.debug("chat.input = value")
        chat.input = value
      }
  }

  func destroyDebounce() {
    cancellable?.cancel()
    chat.input = inputText
  }

  func debounceText(newText: String) {
    DispatchQueue.main.async {
      subject.send(newText)
    }
  }

  func reloadInputArea() {
    inputText = chat.input
  }

  func reuseOrCancel(text: String) {
    if text.isEmpty {
      return
    }

    if inputText.hasSuffix(text + " ") {
      withAnimation(.bouncy) {
        inputText.removeLast((text + " ").count)
      }
      return
    }

    if inputText.hasSuffix(text) {
      withAnimation(.bouncy) {
        inputText.removeLast(text.count)
      }
      return
    }

    if !inputText.isEmpty, !Self.whiteSpaces.contains(inputText.last!) {
      inputText += " "
    }

    if text.count < 300 {
      withAnimation(.bouncy) {
        inputText += text
      }
    } else {
      inputText += text
    }
  }

  func delayClearInput() async {
    Task { @MainActor in
      do {
        try await Task.sleep(for: .milliseconds(100))
        inputText = ""
        AppLogger.ui.debug("inputText cleared")
      } catch {
        AppLogger.error.error("delayClearInput: \(error.localizedDescription)")
      }
    }
  }

  func ask2(text: String, historyCount: Int, model: ModelEntity) {
    // Get provider from model
    let provider = model.provider

    // Build ChatMessage array (unified format)
    var chatMessages: [ChatMessage] = []

    // Add prompt messages first (if any)
    chat.option.prompt?.messages.sorted().reversed().forEach {
      let msgType: ChatMessage.MessageType
      switch $0.role {
      case .assistant:
        msgType = .assistant
      case .user:
        msgType = .user
      case .system:
        msgType = .system
      }
      chatMessages.append(ChatMessage(type: msgType, content: $0.content))
    }

    // Add context messages (history)
    var actualCL = 0
    if historyCount > 0 {
      let hist = self.modelContext.recentMessgagesEarlyOnTop(
        chatId: chat.persistentModelID, limit: historyCount
      )
      actualCL = hist.count

      for item in hist.sorted().reversed() {
        let msgType: ChatMessage.MessageType
        let content = item.message.isMeaningful ? item.message : item.errorInfo
        switch item.role {
        case .user:
          msgType = .user
        case .assistant:
          msgType = .assistant
        case .system:
          msgType = .system
        }
        chatMessages.append(ChatMessage(type: msgType, content: content))
      }
    }

    // Add current user message
    chatMessages.append(ChatMessage(type: .user, content: text))

    // Log message list
    AppLogger.network.debug(
      "using temperature: \(String(describing: chat.option.maybeTemperature)), presencePenalty: \(String(describing: chat.option.maybePresencePenalty)), frequencyPenalty: \(String(describing: chat.option.maybeFrequencyPenalty))"
    )
    AppLogger.network.debug("===whole message list begins===")
    for (i, m) in chatMessages.enumerated() {
      let roleStr: String
      switch m.type {
      case .user: roleStr = "user"
      case .assistant: roleStr = "assistant"
      case .system: roleStr = "system"
      }
      AppLogger.network.debug("\(i).\(roleStr): \(m.content)")
    }
    AppLogger.network.debug("===whole message list ends===")

    // Create user and AI messages in SwiftData
    var userMsg = Message(text, .user, .sending)
    userMsg.chat = chat
    userMsg.meta = .init(
      provider: model.provider.displayName,
      model: model.modelId,
      historyCount: historyCount,
      actual_contextLength: actualCL,
      promptName: chat.option.prompt?.name,
      temperature: chat.option.temperature,
      presencePenalty: chat.option.presencePenalty,
      frequencyPenalty: chat.option.frequencyPenalty,
      promptTokens: nil, completionTokens: nil, startedAt: Date.now, endedAt: nil
    )

    var aiMsg = Message("", .assistant, .thinking)
    aiMsg.chat = chat
    aiMsg.meta = .init(
      provider: model.provider.displayName,
      model: model.modelId,
      historyCount: historyCount,
      actual_contextLength: actualCL,
      promptName: chat.option.prompt?.name,
      temperature: chat.option.temperature,
      presencePenalty: chat.option.presencePenalty,
      frequencyPenalty: chat.option.frequencyPenalty,
      promptTokens: nil, completionTokens: nil, startedAt: nil, endedAt: nil
    )

    do {
      // Save messages to SwiftData
      try modelContext.save()
      userMsg = modelContext.getMessage(messageId: userMsg.id).unsafelyUnwrapped
      aiMsg = modelContext.getMessage(messageId: aiMsg.id).unsafelyUnwrapped
    } catch {
      AppLogger.logError(
        .from(
          error: error,
          operation: "Save message",
          component: "MessageListVM",
          userMessage: "Failed to save, please try again"
        ))
      return
    }

    // Notify new message event
    Task.detached {
      Task { @MainActor in
        em.messageEvent.send(.new)
      }
    }

    // Create service using factory
    let service = ChatStreamingServiceFactory.createService(for: provider.type)

    // Build config based on provider type
    let config: StreamingServiceConfig
    if provider.type == .mock {
      config = .mock(wordCount: 50)
    } else {
      config = .general(
        apiKey: provider.apiKey,
        modelID: model.modelId,
        endpoint: provider.endpoint.isEmpty ? nil : provider.endpoint,
        webSearch: .init(
          enabled: chat.option.webSearchOption?.enabled ?? false,
          contextSize: chat.option.webSearchOption?.contextSize ?? .low,
        ),
        temperature: chat.option.maybeTemperature,
        presencePenalty: chat.option.maybePresencePenalty,
        frequencyPenalty: chat.option.maybeFrequencyPenalty
      )
    }

    let sessionId = UUID().uuidString
    // Call streaming service
    service.streamChatCompletion(
      messages: chatMessages,
      config: config,
      onStart: {
        Task { @MainActor in
          if aiMsg.meta?.startedAt == nil {
            aiMsg.meta?.startedAt = .now
          }
          if userMsg.status == .sending {
            userMsg.onSent()
          }
        }
      },
      onDelta: { deltaText, _ in
        Task { @MainActor in
          if aiMsg.meta?.startedAt == nil {
            aiMsg.meta?.startedAt = .now
          }
          if userMsg.status == .sending {
            userMsg.onSent()
          }

          // Count the number of delta texts
          if let count = countTextCache[sessionId] {
            countTextCache[sessionId] = count + deltaText.count
          } else {
            countTextCache[sessionId] = deltaText.count
          }

          if let cache = deltaTextCache[sessionId] {
            deltaTextCache[sessionId] = cache + deltaText
          } else {
            deltaTextCache[sessionId] = deltaText
          }

          let count = countTextCache[sessionId] ?? 0
          let (identifier, delay): (String, Duration) = switch count {
          case 0..<1000:
            (sessionId + "_low_count", .milliseconds(50))
          case 1000..<2000:
            (sessionId + "_medium_count", .milliseconds(200))
          case 2000..<5000:
            (sessionId + "_high_count", .milliseconds(500))
          default:
            (sessionId + "_max_count", .milliseconds(1000))
          }
          throttle(delay, identifier: identifier, option: .ensureLast) {
            if let cache = deltaTextCache[sessionId], !cache.isEmpty {
              deltaTextCache[sessionId] = ""
              aiMsg.onTyping(text: cache)
            }
          }
        }
      },
      onComplete: { _ in
        Task { @MainActor in
          if let cache = deltaTextCache[sessionId], !cache.isEmpty {
            deltaTextCache[sessionId] = ""
            aiMsg.onTyping(text: cache)
          }

          aiMsg.onEOF(text: "")
          em.messageEvent.send(.eof)
          
          deltaTextCache[sessionId] = ""
          countTextCache[sessionId] = 0
          AppLogger.data.debug("deltaTextCache cleared")

          // Trigger auto-generate title if conditions are met
          TitleGenerationService.shared.generateTitleAuto(chat: chat, modelContext: modelContext)
        }
      },
      onError: { error in
        Task { @MainActor in
          if let cache = deltaTextCache[sessionId], !cache.isEmpty {
            deltaTextCache[sessionId] = ""
            aiMsg.onTyping(text: cache)
          }

          let info = "\(error)"
          if info.lowercased().contains("api key") || info.lowercased().contains("apikey") {
            aiMsg.onError(info, .apiKey)
          } else {
            aiMsg.onError(info, .unknown)
          }
          userMsg.onSent()
          AppLogger.error.error("streaming error: \(error)")
          em.messageEvent.send(.err)

          deltaTextCache[sessionId] = ""
          countTextCache[sessionId] = 0
          AppLogger.data.debug("deltaTextCache cleared")
        }
      }
    )
  }
}
