import Foundation
import os
import SwiftData
import SwiftQueue

final class QueueService {
  static let shared = QueueService()
  
  private var queueManager: SwiftQueueManager?
  private let jobType = OpenRouterModelFetchJob.type
  private let jobId = "openrouter-model-fetch"
  
  private init() {}
  
  func initialize(modelContainer: ModelContainer) {
    // Set ModelContainer in provider
    ModelContainerProvider.shared.setContainer(modelContainer)
    
    // Create JobCreator
    let jobCreator = ModelFetchJobCreator()
    
    // Create SwiftQueueManager
    queueManager = SwiftQueueManagerBuilder(creator: jobCreator)
      .build()
    
    // Schedule the initial job
    scheduleOpenRouterModelFetch()
  }
  
  private func scheduleOpenRouterModelFetch() {
    guard let manager = queueManager else {
      AppLogger.error.error("QueueManager not initialized")
      return
    }
    
    // Cancel any existing job with the same ID
    manager.cancelOperations(uuid: jobId)
    
    // Schedule new job
    // - Run immediately on startup (no delay)
    // - If successful, periodic constraint will schedule next run in 24 hours
    // - If failed, retry constraint will retry with exponential backoff
    JobBuilder(type: jobType)
      .singleInstance(forId: jobId, override: true)
      .internet(atLeast: .cellular)
      .retry(limit: .limited(10)) // Max 10 retries on failure
      .periodic(limit: .unlimited, interval: 24 * 60 * 60) // Repeat every 24 hours after success
      .schedule(manager: manager)
    
    AppLogger.data.info("Scheduled OpenRouter model fetch job (runs immediately on startup, then every 24 hours)")
  }
}

