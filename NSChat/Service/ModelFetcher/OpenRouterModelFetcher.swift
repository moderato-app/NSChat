import Foundation
import os

struct OpenRouterModelFetcher: ModelFetcher {
  func fetchModels(apiKey: String, endpoint: String?) async throws -> [ModelInfo] {
    // Use default endpoint if endpoint is nil, empty, or only whitespace
    let urlString = (endpoint?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
      ? "https://openrouter.ai/api/v1/models"
      : endpoint!
    
    guard let url = URL(string: urlString) else {
      AppLogger.error.error("Invalid URL: \(urlString)")
      throw ModelFetchError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30
    
    AppLogger.logNetworkRequest(url: urlString, method: "GET")
    let startTime = Date()
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    let duration = Date().timeIntervalSince(startTime)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      AppLogger.error.error("Invalid response type")
      throw ModelFetchError.invalidResponse
    }
    
    AppLogger.logNetworkResponse(url: urlString, statusCode: httpResponse.statusCode, duration: duration)
    
    guard httpResponse.statusCode == 200 else {
      throw ModelFetchError.apiError("HTTP \(httpResponse.statusCode)")
    }
    
    struct OpenRouterModelsResponse: Codable {
      struct ModelObject: Codable {
        let id: String
        let name: String?
        let context_length: Int?
        struct TopProvider: Codable {
          let max_completion_tokens: Int?
        }
        let top_provider: TopProvider?
      }
      let data: [ModelObject]
    }
    
    let decoder = JSONDecoder()
    guard let modelsResponse = try? decoder.decode(OpenRouterModelsResponse.self, from: data) else {
      let dataPreview = String(data: data.prefix(200), encoding: .utf8) ?? "Unable to decode as UTF-8"
      AppLogger.error.error("Decoding error | Data size: \(data.count) bytes | Preview: \(dataPreview)")
      throw ModelFetchError.decodingError("Failed to decode OpenRouter models response")
    }
    
    return modelsResponse.data.map { model in
      ModelInfo(
        id: model.id,
        name: model.name ?? model.id,
        inputContextLength: model.context_length,
        outputContextLength: model.top_provider?.max_completion_tokens
      )
    }
  }
}

