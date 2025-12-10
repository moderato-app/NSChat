import Combine
import Foundation
import os
import SwiftData
import Throttler

// MARK: - ChatSendService

final class ChatSendService {
  static let shared = ChatSendService()

  private var deltaTextCache: [String: String] = [:]

  private init() {}

  // MARK: - Send Message

  func sendMessage(
    text: String,
    chat: Chat,
    contextLength: Int,
    model: ModelEntity,
    modelContext: ModelContext,
    em: EM,
    onStreamingMessageCreated: ((PersistentIdentifier) -> Void)? = nil,
    onStreamingUpdate: ((PersistentIdentifier) -> Void)? = nil
  ) {
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
    if contextLength > 0 {
      let hist = modelContext.recentMessgagesEarlyOnTop(chatId: chat.persistentModelID, limit: contextLength)
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
    AppLogger.network.debug("using temperature: \(String(describing: chat.option.maybeTemperature)), presencePenalty: \(String(describing: chat.option.maybePresencePenalty)), frequencyPenalty: \(String(describing: chat.option.maybeFrequencyPenalty))")
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
      contextLength: contextLength,
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
      contextLength: contextLength,
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
      AppLogger.logError(.from(
        error: error,
        operation: "Save message",
        component: "ChatSendService",
        userMessage: "Failed to save, please try again"
      ))
      return
    }

    let aiMsgId = aiMsg.persistentModelID

    // Notify streaming message created
    Task.detached {
      Task { @MainActor in
        onStreamingMessageCreated?(aiMsgId)
      }
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
          contextSize: chat.option.webSearchOption?.contextSize ?? .low
        )
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
      onDelta: { [weak self] deltaText, _ in
        Task { @MainActor in
          guard let self = self else { return }
          if aiMsg.meta?.startedAt == nil {
            aiMsg.meta?.startedAt = .now
          }
          if userMsg.status == .sending {
            userMsg.onSent()
          }
          if let cache = self.deltaTextCache[sessionId] {
            self.deltaTextCache[sessionId] = cache + deltaText
          } else {
            self.deltaTextCache[sessionId] = deltaText
          }
          throttle(.milliseconds(50), identifier: sessionId, option: .ensureLast) {
            if let cache = self.deltaTextCache[sessionId] {
              self.deltaTextCache[sessionId] = ""
              aiMsg.onTyping(text: cache)
              onStreamingUpdate?(aiMsgId)
            }
          }
        }
      },
      onComplete: { _ in
        Task { @MainActor in
          aiMsg.onEOF(text: "")
          onStreamingUpdate?(aiMsgId)
          em.messageEvent.send(.eof)
        }
      },
      onError: { error in
        Task { @MainActor in
          let info = "\(error)"
          if info.lowercased().contains("api key") || info.lowercased().contains("apikey") {
            aiMsg.onError(info, .apiKey)
          } else {
            aiMsg.onError(info, .unknown)
          }
          userMsg.onSent()
          onStreamingUpdate?(aiMsgId)
          AppLogger.error.error("streaming error: \(error)")
          em.messageEvent.send(.err)
        }
      }
    )
  }
}

