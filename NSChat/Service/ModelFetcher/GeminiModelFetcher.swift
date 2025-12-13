import Foundation
import os

struct GeminiModelFetcher: ModelFetcher {
  func fetchModels(apiKey: String, endpoint: String?) async throws -> [ModelInfo] {
    // Gemini doesn't support custom endpoints, always use the official endpoint
    let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    var allModels: [ModelInfo] = []
    var nextPageToken: String? = nil
    var pageCount = 0
    let maxPages = 10 // Safety limit to prevent infinite loops
    
    repeat {
      // Build URL with query parameters
      var urlComponents = URLComponents(string: baseURL)!
      var queryItems: [URLQueryItem] = []
      
      // Add pageSize (max 1000 per page)
      queryItems.append(URLQueryItem(name: "pageSize", value: "1000"))
      
      // Add pageToken if we have one
      if let token = nextPageToken {
        queryItems.append(URLQueryItem(name: "pageToken", value: token))
      }
      
      urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
      
      guard let url = urlComponents.url else {
        AppLogger.error.error("Invalid URL: \(baseURL, privacy: .public)")
        throw ModelFetchError.invalidURL
      }
      
      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      // Gemini uses X-Goog-Api-Key header, not Bearer
      request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
      request.timeoutInterval = 30
      
      AppLogger.logNetworkRequest(url: url.absoluteString, method: "GET")
      let startTime = Date()
      
      let (data, response) = try await URLSession.shared.data(for: request)
      
      let duration = Date().timeIntervalSince(startTime)
      
      guard let httpResponse = response as? HTTPURLResponse else {
        AppLogger.error.error("Invalid response type")
        throw ModelFetchError.invalidResponse
      }
      
      AppLogger.logNetworkResponse(url: url.absoluteString, statusCode: httpResponse.statusCode, duration: duration)
      
      guard httpResponse.statusCode == 200 else {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        AppLogger.error.error("API error: HTTP \(httpResponse.statusCode) - \(errorMessage, privacy: .private)")
        throw ModelFetchError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
      }
      
      // Parse response
      struct GeminiModelsResponse: Codable {
        struct Model: Codable {
          let name: String // Format: "models/{model-id}"
          let baseModelId: String? // Optional - may not be present in all responses
          let version: String?
          let displayName: String?
          let description: String?
          let inputTokenLimit: Int?
          let outputTokenLimit: Int?
          let supportedGenerationMethods: [String]?
        }
        let models: [Model]
        let nextPageToken: String?
      }
      
      let decoder = JSONDecoder()
      let modelsResponse: GeminiModelsResponse
      do {
        modelsResponse = try decoder.decode(GeminiModelsResponse.self, from: data)
      } catch {
        let dataPreview = String(data: data.prefix(500), encoding: .utf8) ?? "Unable to decode as UTF-8"
        AppLogger.error.error("Decoding error | Data size: \(data.count) bytes | Error: \(error.localizedDescription) | Preview: \(dataPreview, privacy: .private)")
        throw ModelFetchError.decodingError("Failed to decode Gemini models response: \(error.localizedDescription)")
      }
      
      // Extract model ID from name field (format: "models/{model-id}")
      // If baseModelId is present, use it; otherwise extract from name
      func extractModelId(from model: GeminiModelsResponse.Model) -> String? {
        if let baseModelId = model.baseModelId, !baseModelId.isEmpty {
          return baseModelId
        }
        // Extract from name: "models/gemini-2.5-flash" -> "gemini-2.5-flash"
        if model.name.hasPrefix("models/") {
          return String(model.name.dropFirst(7)) // Remove "models/" prefix
        }
        return model.name
      }
      
      AppLogger.network.debug(
        "Received \(modelsResponse.models.count) models from API"
      )
      
      // Filter models that support generateContent method
      let supportedModels = modelsResponse.models.filter { model in
        // Must support generateContent
        guard let methods = model.supportedGenerationMethods else { return false }
        let supportsGenerateContent = methods.contains("generateContent")
        if !supportsGenerateContent {
          AppLogger.network.debug(
            "Skipping model \(model.name) - does not support generateContent"
          )
        }
        return supportsGenerateContent
      }
      
      AppLogger.network.debug(
        "\(supportedModels.count) models support generateContent"
      )
      
      // Convert to ModelInfo
      let modelInfos = supportedModels.compactMap { model -> ModelInfo? in
        // Extract model ID (use baseModelId if available, otherwise extract from name)
        guard let modelId = extractModelId(from: model) else {
          AppLogger.network.debug("Skipping model with invalid name: \(model.name)")
          return nil
        }
        
        // Use displayName if available, otherwise use modelId
        let name = model.displayName ?? modelId
        return ModelInfo(
          id: modelId,
          name: name,
          inputContextLength: model.inputTokenLimit,
          outputContextLength: model.outputTokenLimit
        )
      }
      
      AppLogger.network.debug(
        "Converted \(modelInfos.count) models to ModelInfo"
      )
      
      allModels.append(contentsOf: modelInfos)
      nextPageToken = modelsResponse.nextPageToken
      pageCount += 1
      
      AppLogger.network.info(
        "Fetched page \(pageCount) - \(modelInfos.count) models (total: \(allModels.count))"
      )
      
    } while nextPageToken != nil && pageCount < maxPages
    
    if pageCount >= maxPages {
      AppLogger.network.warning(
        "Reached max pages limit (\(maxPages)), stopping pagination"
      )
    }
    
    AppLogger.network.info(
      "✅ Fetched \(allModels.count) models in \(pageCount) page(s)"
    )
    
    return allModels
  }
}
