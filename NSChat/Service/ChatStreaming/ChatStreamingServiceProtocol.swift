import Foundation

/// Chat message structure for API requests
struct ChatMessage {
  enum MessageType {
    case user
    case assistant
    case system
  }
  
  let type: MessageType
  let content: String
}

/// Streaming service configuration
struct StreamingServiceConfig {
  /// API Key (OpenAI, OpenRouter, etc. need this)
  let apiKey: String?
  
  /// Model ID (OpenAI, OpenRouter, etc. need this)
  let modelID: String?
  
  /// Custom endpoint URL (OpenAI supports this)
  let endpoint: String?
  
  /// Word count for Mock provider
  let wordCount: Int?
  
  /// Web search options
  let webSearch: WebSearchOptionConfig?
  
  /// Temperature parameter (0-2, higher = more random)
  let temperature: Double?
  
  /// Presence penalty (-2.0 to 2.0, positive = penalize new tokens)
  let presencePenalty: Double?
  
  /// Frequency penalty (-2.0 to 2.0, positive = penalize repetition)
  let frequencyPenalty: Double?
   
  /// Create config for general providers (OpenAI, OpenRouter, etc.)
  static func general(
    apiKey: String,
    modelID: String,
    endpoint: String?,
    webSearch: WebSearchOptionConfig?,
    temperature: Double? = nil,
    presencePenalty: Double? = nil,
    frequencyPenalty: Double? = nil
  ) -> StreamingServiceConfig {
    return StreamingServiceConfig(
      apiKey: apiKey,
      modelID: modelID,
      endpoint: endpoint,
      wordCount: nil,
      webSearch: webSearch,
      temperature: temperature,
      presencePenalty: presencePenalty,
      frequencyPenalty: frequencyPenalty
    )
  }
  
  /// Create config for Mock
  static func mock(wordCount: Int = 50) -> StreamingServiceConfig {
    return StreamingServiceConfig(
      apiKey: nil,
      modelID: nil,
      endpoint: nil,
      wordCount: wordCount,
      webSearch: nil,
      temperature: nil,
      presencePenalty: nil,
      frequencyPenalty: nil
    )
  }
}

struct WebSearchOptionConfig {
  let enabled: Bool
  let contextSize: WebSearchContextSize
}

/// Protocol for streaming chat completion services
/// All provider implementations must conform to this protocol
protocol ChatStreamingServiceProtocol {
  /// Send streaming chat completion request
  /// - Parameters:
  ///   - messages: Message history
  ///   - config: Service configuration (API key, model ID, etc.)
  ///   - onStart: Callback when streaming starts
  ///   - onDelta: Callback for each delta text chunk (deltaText, fullText)
  ///   - onComplete: Callback when streaming completes
  ///   - onError: Callback when an error occurs
  func streamChatCompletion(
    messages: [ChatMessage],
    config: StreamingServiceConfig,
    onStart: @escaping () -> Void,
    onDelta: @escaping (String, String) -> Void,
    onComplete: @escaping (String) -> Void,
    onError: @escaping (Error) -> Void
  )
}

