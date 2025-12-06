import Foundation
import SwiftQueue

final class ModelFetchJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> Job {
    if type == OpenRouterModelFetchJob.type {
      return OpenRouterModelFetchJob(params: params)
    }
    
    fatalError("Unknown job type: \(type)")
  }
}

