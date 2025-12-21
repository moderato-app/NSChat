import Foundation
import SwiftData

extension Provider {
  /// Synchronizes the provider's models with fetched model information
  /// - Parameters:
  ///   - modelInfos: Array of fetched model information
  ///   - modelContext: The model context for database operations
  ///
  /// Rules:
  /// - If model with same ID exists and is not custom: update its properties
  /// - If model doesn't exist: add new model
  /// - If model exists but not in fetched list and is not custom: delete it
  /// - Custom models are never updated or deleted
  func syncModels(with modelInfos: [ModelInfo], in modelContext: ModelContext) {
    let existingModels = models
    
    var toAdd: [ModelEntity] = []
    var toDel: [ModelEntity] = []
    
    // Process each fetched model
    for modelInfo in modelInfos {
      let matchingModels = existingModels.filter {
        $0.modelId == modelInfo.id && !$0.isCustom
      }
      
      if matchingModels.isEmpty {
        // No matching model found - create new one
        let newModel = ModelEntity(
          provider: self,
          modelId: modelInfo.id,
          modelName: modelInfo.name,
          inputContextLength: modelInfo.inputContextLength,
          outputContextLength: modelInfo.outputContextLength
        )
        toAdd.append(newModel)
      } else {
        // Found matching model(s) - update the first one and delete duplicates
        // Keep only custom models (even though we filtered them out above)
        let customs = matchingModels.filter { $0.isCustom }
        if !customs.isEmpty {
          // If there are custom models, delete non-custom duplicates
          matchingModels.filter { !customs.contains($0) }.forEach {
            toDel.append($0)
          }
          continue
        }
        
        // Update the first matching model
        if let first = matchingModels.first {
          first.modelName = modelInfo.name
          first.inputContextLength = modelInfo.inputContextLength
          first.outputContextLength = modelInfo.outputContextLength
          
          // Delete any duplicate models
          matchingModels.filter { $0 != first }.forEach {
            toDel.append($0)
          }
        }
      }
    }
    
    // Find models that should be deleted (not in fetched list and not custom)
    let modelIDs = Set(modelInfos.map { $0.id })
    let modelsToDelete = existingModels.filter { !$0.isCustom && !modelIDs.contains($0.modelId) }
    toDel.append(contentsOf: modelsToDelete)
    
    // Remove and delete models marked for deletion
    for del in toDel {
      models.removeAll(where: { del == $0 })
      modelContext.delete(del)
    }
    
    // Add new models
    for newModel in toAdd {
      modelContext.insert(newModel)
      models.append(newModel)
    }

    // Log the sync operation
    if !toAdd.isEmpty || !toDel.isEmpty {
      AppLogger.data.info("Synced models for \(displayName): added \(toAdd.count), deleted \(toDel.count)")
    }
    
    do {
      try modelContext.save()
    } catch {
      AppLogger.logError(.from(
        error: error,
        operation: "Save models to provider",
        component: "ProviderView"
      ))
    }
  }
}
