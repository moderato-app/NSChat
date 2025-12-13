import AIProxy
import Foundation
import os

/// OpenRouter streaming service
/// Handles streaming chat completion requests using AIProxySwift
class OpenRouterStreamingService: ChatStreamingServiceProtocol {
  // MARK: - Properties
  
  /// Background queue for handling streaming requests
  private let streamingQueue = DispatchQueue(
    label: bundleName + ".openrouterstreaming",
    qos: .userInitiated
  )
  
  // MARK: - Public Methods
  
  func streamChatCompletion(
    messages: [ChatMessage],
    config: StreamingServiceConfig,
    onStart: @escaping () -> Void,
    onDelta: @escaping (String, String) -> Void,
    onComplete: @escaping (String) -> Void,
    onError: @escaping (Error) -> Void
  ) {
    streamingQueue.async {
      Task {
        // Validate required config parameters
        guard let apiKey = config.apiKey, let modelID = config.modelID else {
          AppLogger.error.error(
            "❌ Config error: missing apiKey or modelID"
          )
          DispatchQueue.main.async {
            onError(NSError(
              domain: "OpenRouterStreamingService",
              code: -1,
              userInfo: [NSLocalizedDescriptionKey: "Missing apiKey or modelID in config"]
            ))
          }
          return
        }
        
        do {
          AppLogger.network.info(
            "[OpenRouterStreamingService] 🚀 Starting streaming request - Model: \(modelID)"
          )
          
          // Create OpenRouter service (BYOK mode)
          // Note: OpenRouter doesn't support custom endpoints in AIProxySwift
          let openRouterService = AIProxy.openRouterDirectService(
            unprotectedAPIKey: apiKey
          )
          
          // Convert messages to OpenRouter format
          let requestMessages = messages.map { message -> OpenRouterChatCompletionRequestBody.Message in
            switch message.type {
            case .user:
              return .user(content: .text(message.content))
            case .assistant:
              return .assistant(content: .text(message.content))
            case .system:
              return .system(content: .text(message.content))
            }
          }
          
          if config.webSearch?.enabled == true {
            AppLogger.network.info("ℹ️ Web search requested but not supported for OpenRouter; sending without web search.")
          }
          
          // Build request body
          let requestBody = OpenRouterChatCompletionRequestBody(
            messages: requestMessages,
            frequencyPenalty: config.frequencyPenalty,
            model: modelID,
            presencePenalty: config.presencePenalty,
            stream: true,
            temperature: config.temperature,
          )
          
          // Notify start
          DispatchQueue.main.async {
            onStart()
          }
          
          // Initiate streaming request
          let stream = try await openRouterService.streamingChatCompletionRequest(
            body: requestBody,
            secondsToWait: 60
          )
          
          var accumulatedText = ""
          
          // Process streaming response
          for try await chunk in stream {
            if let deltaContent = chunk.choices.first?.delta.content {
              accumulatedText += deltaContent
              
              // Callback with delta text (capture value before async to avoid concurrency issues)
              let currentAccumulated = accumulatedText
              DispatchQueue.main.async {
                onDelta(deltaContent, currentAccumulated)
              }
            }
            
            // Check if completed
            if let finishReason = chunk.choices.first?.finishReason {
              AppLogger.network.info(
                "[OpenRouterStreamingService] ✅ Streaming request completed - Reason: \(finishReason), Total length: \(accumulatedText.count)"
              )
              
              DispatchQueue.main.async {
                onComplete(accumulatedText)
              }
              break
            }
          }
          
        } catch let AIProxyError.unsuccessfulRequest(statusCode, responseBody) {
          let errorMessage = "OpenRouter API Error: \(statusCode) - \(responseBody)"
          AppLogger.error.error(
            "❌ API request failed: \(errorMessage, privacy: .private)"
          )
          
          DispatchQueue.main.async {
            onError(NSError(
              domain: "OpenRouterStreamingService",
              code: statusCode,
              userInfo: [NSLocalizedDescriptionKey: errorMessage]
            ))
          }
          
        } catch {
          AppLogger.error.error(
            "❌ Streaming request failed: \(error.localizedDescription, privacy: .private)"
          )
          
          DispatchQueue.main.async {
            onError(error)
          }
        }
      }
    }
  }
}
