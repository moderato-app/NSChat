import Foundation
import os
import SwiftData

struct ProviderModelFetchService {
  let modelContext: ModelContext
  
  func fetchModels(
    providerType: ProviderType,
    apiKey: String,
    endpoint: String?
  ) async throws -> [ModelInfo] {
    // First, try to fetch models using the provider's own fetcher
    var fetchedModels: [ModelInfo] = []
    
    do {
      let fetcher = providerType.createFetcher()
      fetchedModels = try await fetcher.fetchModels(
        apiKey: apiKey,
        endpoint: endpoint?.isEmpty == true ? nil : endpoint
      )
      AppLogger.data.info("Fetched \(fetchedModels.count) models from provider API")
    } catch {
      AppLogger.logError(.from(
        error: error,
        operation: "Fetch models from provider",
        component: "ProviderModelFetchService"
      ))
    }
    
    // If no models were fetched, try OpenRouter fallback
    if fetchedModels.isEmpty, let prefix = providerType.openRouterPrefix {
      fetchedModels = try await fetchModelsFromOpenRouterFallback(
        prefix: prefix,
        apiKey: apiKey
      )
    }
    
    return fetchedModels
  }
  
  private func fetchModelsFromOpenRouterFallback(
    prefix: String,
    apiKey: String
  ) async throws -> [ModelInfo] {
    var fetchedModels: [ModelInfo] = []
    
    // First, try to get OpenRouter models from database
    let descriptor = FetchDescriptor<OpenRouterModel>()
    let dbModels = try? modelContext.fetch(descriptor)
    
    if let dbModels = dbModels, !dbModels.isEmpty {
      // Convert database models to ModelInfo and filter by prefix
      let allOpenRouterModels = dbModels.map { model in
        ModelInfo(
          id: model.modelId,
          name: model.modelName,
          inputContextLength: model.inputContextLength,
          outputContextLength: model.outputContextLength
        )
      }
      
      let filteredModels = filterAndRemovePrefix(
        models: allOpenRouterModels,
        prefix: prefix
      )
      
      if !filteredModels.isEmpty {
        fetchedModels = filteredModels
        AppLogger.data.info("Fetched \(filteredModels.count) models from database filtered by prefix '\(prefix)/'")
      }
    }
    
    // If database has no models, fetch from OpenRouter API
    if fetchedModels.isEmpty {
      var allOpenRouterModels: [ModelInfo] = []
      
      // Try with empty API key first (some endpoints allow public access)
      do {
        let openRouterFetcher = OpenRouterModelFetcher()
        allOpenRouterModels = try await openRouterFetcher.fetchModels(
          apiKey: "",
          endpoint: nil
        )
        AppLogger.data.info("Fetched OpenRouter models with public access")
      } catch {
        // If that fails, try with provider's API key
        do {
          let openRouterFetcher = OpenRouterModelFetcher()
          allOpenRouterModels = try await openRouterFetcher.fetchModels(
            apiKey: apiKey,
            endpoint: nil
          )
          AppLogger.data.info("Fetched OpenRouter models with provider API key")
        } catch {
          AppLogger.logError(.from(
            error: error,
            operation: "Fetch models from OpenRouter",
            component: "ProviderModelFetchService"
          ))
        }
      }
      
      // Filter by prefix and remove prefix from model ID
      if !allOpenRouterModels.isEmpty {
        fetchedModels = filterAndRemovePrefix(
          models: allOpenRouterModels,
          prefix: prefix
        )
        AppLogger.data.info("Fetched \(fetchedModels.count) models from OpenRouter API filtered by prefix '\(prefix)/'")
      }
    }
    
    return fetchedModels
  }
  
  private func filterAndRemovePrefix(
    models: [ModelInfo],
    prefix: String
  ) -> [ModelInfo] {
    let prefixWithSlash = "\(prefix)/"
    return models
      .filter { modelInfo in
        modelInfo.id.hasPrefix(prefixWithSlash)
      }
      .map { modelInfo in
        // Remove prefix from model ID
        let modelIdWithoutPrefix = String(modelInfo.id.dropFirst(prefixWithSlash.count))
        return ModelInfo(
          id: modelIdWithoutPrefix,
          name: modelInfo.name,
          inputContextLength: modelInfo.inputContextLength,
          outputContextLength: modelInfo.outputContextLength
        )
      }
  }
}
