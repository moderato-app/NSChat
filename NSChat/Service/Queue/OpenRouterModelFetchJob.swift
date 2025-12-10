import Foundation
import os
import SwiftData
import SwiftQueue

final class OpenRouterModelFetchJob: Job {
  static let type = "OpenRouterModelFetchJob"
  
  private weak var modelContainerProvider: ModelContainerProvider?
  
  required init(params: [String: Any]?) {
    // ModelContainer will be provided by ModelContainerProvider singleton
    // params parameter is required by Job protocol but not used
    _ = params
    self.modelContainerProvider = ModelContainerProvider.shared
  }
  
  func onRun(callback: JobResult) {
    Task {
      do {
        guard let modelContainer = modelContainerProvider?.container else {
          AppLogger.error.error("[OpenRouterModelFetchJob] ModelContainer not available")
          callback.done(.fail(NSError(domain: "OpenRouterModelFetchJob", code: -1, userInfo: [NSLocalizedDescriptionKey: "ModelContainer not available"])))
          return
        }
        
        // Create a new ModelContext for this background thread
        let modelContext = ModelContext(modelContainer)
        
        // Find OpenRouter provider
        let descriptor = FetchDescriptor<OpenRouterModel>()
        
        let oldORModels = try? modelContext.fetch(descriptor)
        
        // Fetch models from OpenRouter
        let fetcher = OpenRouterModelFetcher()
        let models = try await fetcher.fetchModels(apiKey: "", endpoint: nil)

        guard !models.isEmpty else {
          AppLogger.error.error("[OpenRouterModelFetchJob] No models fetched from OpenRouter")
          callback.done(.fail(NSError(domain: "OpenRouterModelFetchJob", code: -1, userInfo: [NSLocalizedDescriptionKey: "No models fetched from OpenRouter"])))
          return
        }
        
        if let oldORModels {
          // Clear existing models for this provider (only non-custom models)
          for model in oldORModels {
            modelContext.delete(model)
          }
        }
        
        // Save new models
        for modelInfo in models {
          let modelEntity = OpenRouterModel(
            modelId: modelInfo.id,
            modelName: modelInfo.name,
            inputContextLength: modelInfo.inputContextLength,
            outputContextLength: modelInfo.outputContextLength,
          )
          modelContext.insert(modelEntity)
        }
        
        // Save changes
        try modelContext.save()
        
        AppLogger.data.info("[OpenRouterModelFetchJob] Successfully fetched and saved \(models.count) OpenRouter models")
        callback.done(.success)
      } catch {
        AppLogger.logError(.from(
          error: error,
          operation: "Fetch OpenRouter models",
          component: "OpenRouterModelFetchJob"
        ))
        callback.done(.fail(error))
      }
    }
  }
  
  func onRetry(error: Error) -> RetryConstraint {
    // Retry with exponential backoff: 1 minute, 2 minutes, 4 minutes, etc., max 1 hour
    return .exponentialWithLimit(initial: 2, maxDelay: 3600)
  }
  
  func onRemove(result: JobCompletion) {
    switch result {
    case .success:
      AppLogger.data.info("[OpenRouterModelFetchJob] Job completed successfully")
    case .fail(let error):
      AppLogger.error.error("[OpenRouterModelFetchJob] Job failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
