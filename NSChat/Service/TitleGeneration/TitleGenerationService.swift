import Foundation
import os
import SwiftData

/// Service to automatically generate chat titles based on conversation content
final class TitleGenerationService {
  static let shared = TitleGenerationService()
  
  private init() {}
  
  /// Generates a title for the chat if conditions are met (auto mode)
  /// - Parameters:
  ///   - chat: The chat to generate a title for
  ///   - modelContext: The SwiftData model context
  func generateTitleAuto(chat: Chat, modelContext: ModelContext) {
    // Check condition 1: User has enabled auto-generate title
    guard Pref.shared.autoGenerateTitle else {
      AppLogger.data.debug("[TitleGenerationService] Auto-generate title is disabled")
      return
    }
    
    // Check condition 2: Chat name is still the default "New Chat"
    guard chat.name == ChatConstants.DEFAULT_CHAT_NAME else {
      AppLogger.data.debug("[TitleGenerationService] Chat name is not default, skipping title generation")
      return
    }
    
    // Check condition 3: This is one of the first 3 AI messages
    guard chat.messages.count < 6 else {
      AppLogger.data.debug("[TitleGenerationService] Chat has more than 5 messages, skipping title generation")
      return
    }
    
    // Call the core generation function
    generateTitleCore(chat: chat, modelContext: modelContext)
  }
  
  /// Manually generates a title for the chat (skips most checks)
  /// - Parameters:
  ///   - chat: The chat to generate a title for
  ///   - modelContext: The SwiftData model context
  ///   - onStart: Optional callback when generation starts
  ///   - onComplete: Optional callback when generation completes (success or failure)
  func generateTitleManually(
    chat: Chat,
    modelContext: ModelContext,
    onStart: (() -> Void)? = nil,
    onComplete: (() -> Void)? = nil
  ) {
    AppLogger.data.info("[TitleGenerationService] Manual title generation requested")
    generateTitleCore(chat: chat, modelContext: modelContext, onStart: onStart, onComplete: onComplete)
  }
  
  /// Core title generation logic (shared between auto and manual modes)
  /// - Parameters:
  ///   - chat: The chat to generate a title for
  ///   - modelContext: The SwiftData model context
  ///   - onStart: Optional callback when generation starts
  ///   - onComplete: Optional callback when generation completes (success or failure)
  private func generateTitleCore(
    chat: Chat,
    modelContext: ModelContext,
    onStart: (() -> Void)? = nil,
    onComplete: (() -> Void)? = nil
  ) {
    // Check condition: Selected model exists
    guard let model = chat.option.model else {
      AppLogger.data.debug("[TitleGenerationService] No model selected, cannot generate title")
      return
    }
    
    // Extract last 6 messages with preview (first 100 chars)
    let allMessages = Array(chat.messages.sorted().suffix(6))
    var messageSnippets: [String] = []
    
    for message in allMessages {
      let roleString: String
      switch message.role {
      case .user:
        roleString = "User"
      case .assistant:
        roleString = "Assistant"
      case .system:
        roleString = "System"
      }
      messageSnippets.append("\(roleString): \(message.preview)")
    }
    
    // Build prompt for title generation
    let conversationContext = messageSnippets.joined(separator: "\n")
    
    let prompt: String
    if chat.name == ChatConstants.DEFAULT_CHAT_NAME {
      // First time generation
      prompt = """
      Based on the following conversation, generate a concise title that match the language of the following conversation (max 20 characters):
      
      \(conversationContext)
      
      Reply with only the title, nothing else.
      """
    } else {
      // Regenerate with different title
      prompt = """

      Current title: "\(chat.name)"
      
      Generate a different title that better reflects what the user want to discuss.

      Based on the following conversation, generate a concise title that match the language of the following conversation (max 40 characters).
      
      \(conversationContext)
      
      Reply with only the title, nothing else.
      """
    }

    AppLogger.data.debug("[TitleGenerationService] Prompt: \(prompt)")
        
    // Prepare messages for API call
    let chatMessages = [ChatMessage(type: .user, content: prompt)]
    
    // Get provider from model
    let provider = model.provider
    
    // Build config
    let config: StreamingServiceConfig
    if provider.type == .mock {
      config = .mock(wordCount: 10)
    } else {
      config = .general(
        apiKey: provider.apiKey,
        modelID: model.modelId,
        endpoint: provider.endpoint.isEmpty ? nil : provider.endpoint,
        webSearch: nil
      )
    }
    
    // Create streaming service
    let service = ChatStreamingServiceFactory.createService(for: provider.type)
       
    // Call streaming service
    service.streamChatCompletion(
      messages: chatMessages,
      config: config,
      onStart: {
        AppLogger.data.debug("[TitleGenerationService] Title generation started")
        Task { @MainActor in
          onStart?()
        }
      },
      onDelta: { _, _ in
      },
      onComplete: { finalText in
        Task { @MainActor in
          // Clean up the title (remove quotes, trim, limit to 20 chars)
          var cleanTitle = finalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
          
          if cleanTitle.count > 100 {
            cleanTitle = String(cleanTitle.prefix(100))
          }
          
          // Update chat name if we got a valid title
          if !cleanTitle.isEmpty {
            chat.name = cleanTitle
            chat.updatedAt = Date.now
            
            do {
              try modelContext.save()
              AppLogger.data.info("[TitleGenerationService] Title generated successfully: \(cleanTitle)")
            } catch {
              AppLogger.logError(.from(
                error: error,
                operation: "Save generated title",
                component: "TitleGenerationService",
                userMessage: nil
              ))
            }
          } else {
            AppLogger.data.warning("[TitleGenerationService] Generated title is empty, keeping default name")
          }
          
          onComplete?()
        }
      },
      onError: { error in
        Task { @MainActor in
          AppLogger.error.error("[TitleGenerationService] Failed to generate title: \(error.localizedDescription)")
          onComplete?()
        }
      }
    )
  }
}
