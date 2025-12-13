import AIProxy
import Foundation
import os

/// OpenAI streaming service
/// Handles streaming chat completion requests using AIProxySwift
class OpenAIStreamingService: ChatStreamingServiceProtocol {
  // MARK: - Properties
  
  /// Background queue for handling streaming requests
  private let streamingQueue = DispatchQueue(
    label: bundleName + ".openaistreaming",
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
              domain: "OpenAIStreamingService",
              code: -1,
              userInfo: [NSLocalizedDescriptionKey: "Missing apiKey or modelID in config"]
            ))
          }
          return
        }
        
        do {
          AppLogger.network.info(
            "🚀 Starting streaming request - Model: \(modelID)"
          )
          
          // Create OpenAI service (BYOK mode)
          let openAIService: OpenAIService
          if let endpoint = config.endpoint, !endpoint.isEmpty {
            do {
              let res = try parseURL(endpoint)
              // Log endpoint base URL for diagnosis (without query params)
              AppLogger.network.debug(
                "Using custom endpoint: \(res.base, privacy: .sensitive)"
              )
              openAIService = AIProxy.openAIDirectService(
                unprotectedAPIKey: apiKey,
                baseURL: res.base
              )
            } catch {
              AppLogger.logError(.from(
                error: error,
                operation: "Parse endpoint URL",
                component: "OpenAIStreamingService",
                userMessage: nil
              ))
              openAIService = AIProxy.openAIDirectService(unprotectedAPIKey: apiKey)
            }
          } else {
            openAIService = AIProxy.openAIDirectService(unprotectedAPIKey: apiKey)
          }
          
          // Convert messages to OpenAI format
          let inputItems = messages.map { message -> OpenAIResponse.Input.InputItem in
            switch message.type {
            case .user:
              return .message(role: .user, content: .text(message.content))
            case .assistant:
              return .message(role: .assistant, content: .text(message.content))
            case .system:
              return .message(role: .system, content: .text(message.content))
            }
          }
          let input = OpenAIResponse.Input.items(inputItems)
          // Build request body
          let tools: [OpenAICreateResponseRequestBody.Tool]?
          if let webSearch = config.webSearch, webSearch.enabled {
            tools = [
              .webSearch(
                .init(
                  searchContextSize: mapSearchContextSize(webSearch.contextSize),
                  userLocation: nil
                )
              )
            ]
          } else {
            tools = nil
          }
          
          let requestBody = OpenAICreateResponseRequestBody(
            input: input,
            model: modelID,
            stream: true,
            temperature: config.temperature,
            tools: tools
          )
          
          // Log request configuration for diagnosis
          AppLogger.network.debug(
            "Request config",
            context: [
              "messages": messages.count,
              "temperature": config.temperature?.description ?? "nil",
              "tools": tools != nil ? "enabled" : "disabled"
            ]
          )
          
          // Notify start
          DispatchQueue.main.async {
            onStart()
          }
          
          // Initiate streaming request
          let stream = try await openAIService.createStreamingResponse(requestBody: requestBody, secondsToWait: 60)
          
          var accumulatedText = ""
          var isCompleted = false
          
          // Process streaming response
          for try await event in stream {
            switch event {
            // Text delta - most important event for streaming content
            case .outputTextDelta(let textDelta):
              accumulatedText += textDelta.delta
              
              let currentAccumulated = accumulatedText
              DispatchQueue.main.async {
                onDelta(textDelta.delta, currentAccumulated)
              }
              
              AppLogger.network.debug(
                "📝 Text delta received",
                context: [
                  "Length": textDelta.delta.count,
                  "Value": "\(textDelta.delta, privacy: .private)"
                ]
              )
            
            // Response completed - marks successful completion
            case .responseCompleted(let completed):
              AppLogger.network.info(
                "✅ Response completed",
                context: [
                  "ID": "\(completed.response.id ?? "unknown", privacy: .sensitive)",
                  "Total length": accumulatedText.count,
                  "Content": "\(accumulatedText, privacy: .private)"
                ]
              )
              
              isCompleted = true
              DispatchQueue.main.async {
                onComplete(accumulatedText)
              }
            
            // Error event - handle API errors
            case .error(let errorEvent):
              AppLogger.error.error(
                "❌ Error event",
                context: [
                  "Code": errorEvent.code,
                  "Message": "\(errorEvent.message, privacy: .public)"
                ]
              )
              
              DispatchQueue.main.async {
                onError(NSError(
                  domain: "OpenAIStreamingService",
                  code: -1,
                  userInfo: [NSLocalizedDescriptionKey: errorEvent.message]
                ))
              }
            
            // Response failed - handle failed responses
            case .responseFailed(let failed):
              AppLogger.error.error(
                "❌ Response failed",
                context: [
                  "ID": "\(failed.response.id ?? "unknown", privacy: .sensitive)",
                  "Error description": "\(String(describing: failed.response.error), privacy: .public)"
                ]
              )
                            
              DispatchQueue.main.async {
                onError(NSError(
                  domain: "OpenAIStreamingService",
                  code: -1,
                  userInfo: [NSLocalizedDescriptionKey: "Response failed: \(failed.response.error.debugDescription)"]
                ))
              }
            
            // Lifecycle events - log for debugging
            case .responseCreated(let created):
              AppLogger.network.debug(
                "🎬 Response created",
                context: [
                  "ID": "\(created.response.id ?? "unknown", privacy: .sensitive)",
                  "Sequence number": created.sequenceNumber ?? -1
                ]
              )
              
            case .responseInProgress:
              AppLogger.network.debug("🔄 Response in progress")
              
            case .responseIncomplete:
              AppLogger.network.warning("⚠️ Response incomplete")
            
            // Web search events - log search activity
            case .webSearchCallInProgress:
              AppLogger.network.info("🔍 Web search in progress")
              
            case .webSearchCallSearching:
              AppLogger.network.info("🔍 Web search searching")
              
            case .webSearchCallCompleted:
              AppLogger.network.info("✅ Web search completed")
            
            // Output item events - track output structure
            case .outputItemAdded(let item):
              AppLogger.network.debug(
                "➕ Output item added - Index: \(item.index ?? -1)"
              )
              
            case .outputItemDone(let item):
              AppLogger.network.debug(
                "✓ Output item done - Index: \(item.outputIndex ?? -1)"
              )
            
            // Content part events - track content structure
            case .contentPartAdded(let part):
              AppLogger.network.debug(
                "➕ Content part added - Index: \(part.contentIndex ?? -1)"
              )
              
            case .contentPartDone(let part):
              AppLogger.network.debug(
                "✓ Content part done - Index: \(part.contentIndex ?? -1)"
              )
            
            // Text completion - marks end of text
            case .outputTextDone(let textDone):
              AppLogger.network.debug(
                "✓ Text done - Length: \(textDone.text.count)"
              )
            
            // Refusal events - log when model refuses
            case .refusalDelta(let refusal):
              AppLogger.network.warning("🚫 Refusal delta", context: [
                "count": refusal.delta.count,
                "value": "\(refusal.delta, privacy: .private)"
              ])
              
            case .refusalDone(let refusal):
              AppLogger.network.warning(
                "🚫 Refusal done",
                context: [
                  "Length": refusal.refusal.count,
                  "Content": "\(refusal.refusal, privacy: .private)"
                ]
              )
            
            // Function call events - log function calling activity
            case .functionCallArgumentsDelta(let args):
              AppLogger.network.debug(
                "🔧 Function args delta - Length: \(args.delta.count)"
              )
              
            case .functionCallArgumentsDone(let args):
              AppLogger.network.debug(
                "✓ Function args done - Length: \(args.arguments.count)"
              )
            
            // File search events - log file search activity
            case .fileSearchCallInProgress:
              AppLogger.network.info("📁 File search in progress")
              
            case .fileSearchCallSearching:
              AppLogger.network.info("📁 File search searching")
              
            case .fileSearchCallCompleted:
              AppLogger.network.info("✅ File search completed")
            
            // Reasoning events - log reasoning process
            case .reasoningDelta(let reasoning):
              AppLogger.network.debug(
                "🧠 Reasoning delta - Length: \(reasoning.delta.count)"
              )
              
            case .reasoningDone(let reasoning):
              AppLogger.network.debug(
                "✓ Reasoning done - Length: \(reasoning.reasoning.count)"
              )
            
            // Other events we don't need to handle but log for debugging
            case .outputTextAnnotationAdded:
              AppLogger.network.debug("📎 Text annotation added")
              
            case .audioDelta, .audioDone, .audioTranscriptDelta, .audioTranscriptDone:
              AppLogger.network.debug("🎵 Audio event")
              
            case .codeInterpreterCallProgress:
              AppLogger.network.debug("💻 Code interpreter progress")
              
            case .computerCallProgress:
              AppLogger.network.debug("🖥️ Computer call progress")
              
            case .reasoningSummaryPartAdded, .reasoningSummaryPartDone,
                 .reasoningSummaryTextDelta, .reasoningSummaryTextDone,
                 .reasoningSummaryDelta, .reasoningSummaryDone:
              AppLogger.network.debug("📊 Reasoning summary event")
              
            case .imageGenerationCallProgress, .imageGenerationCallPartialImage:
              AppLogger.network.debug("🎨 Image generation event")
              
            case .mcpCallArgumentsDelta, .mcpCallArgumentsDone,
                 .mcpCallProgress, .mcpListToolsProgress:
              AppLogger.network.debug("🔌 MCP event")
              
            case .responseQueued:
              AppLogger.network.debug("⏳ Response queued")
            }
          }
          
          // If loop ended without completion event, call onComplete anyway
          if !isCompleted && accumulatedText.isEmpty == false {
            AppLogger.network.info(
              "✅ Stream ended without completion event",
              context: [
                "Total length": accumulatedText.count,
                "Content": "\(accumulatedText, privacy: .private)"
              ]
            )
            DispatchQueue.main.async {
              onComplete(accumulatedText)
            }
          }
          
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
          // Log error details for diagnosis
          AppLogger.error.error(
            "❌ API request failed",
            context: [
              "Status": statusCode,
              "Response length": responseBody.count,
              "Body": "\(responseBody, privacy: .sensitive)"
            ]
          )
          
          let errorMessage = "OpenAI API Error: \(statusCode) - \(responseBody)"
          DispatchQueue.main.async {
            onError(NSError(
              domain: "OpenAIStreamingService",
              code: statusCode,
              userInfo: [NSLocalizedDescriptionKey: errorMessage]
            ))
          }
          
        } catch {
          // Log error details for diagnosis
          let errorTypeName = String(describing: type(of: error))
          AppLogger.error.error(
            "❌ Streaming request failed",
            context: [
              "Type": errorTypeName,
              "Message": "\(error.localizedDescription, privacy: .public)"
            ]
          )

          DispatchQueue.main.async {
            onError(error)
          }
        }
      }
    }
  }
}

private func mapSearchContextSize(_ size: WebSearchContextSize) -> OpenAICreateResponseRequestBody.WebSearchTool.SearchContextSize {
  switch size {
  case .high:
    return .high
  case .medium:
    return .medium
  case .low:
    return .low
  }
}
