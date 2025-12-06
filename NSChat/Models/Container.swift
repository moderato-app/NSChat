import Foundation
import os
import SwiftData

let allSchema = Schema([
  Chat.self,
  ChatOption.self,
  WebSearch.self,
  Prompt.self,
  PromptMessage.self,
  Provider.self,
  ModelEntity.self,
  UsedModel.self,
  OpenRouterModel.self
])

extension ModelContainer {
  static var preview: () -> ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    var container: ModelContainer
    do {
      container = try ModelContainer(for: allSchema, configurations: [configuration])
    } catch {
      fatalError("failed to configure the container")
    }
    let c = container
    Task { @MainActor in
      AppLogger.data.debug("\(c.mainContext.sqliteCommand)")
      try migrate(c.mainContext)
      try addPreviewData(c.mainContext)
    }
    return container
  }

  static var product: () -> ModelContainer = {
    var container: ModelContainer
    do {
      container = try ModelContainer(for: allSchema)
    } catch {
      fatalError("failed to configure the container")
    }
    let c = container
    Task { @MainActor in
      AppLogger.data.debug("\(c.mainContext.sqliteCommand)")
      try migrate(c.mainContext)
    }
    return container
  }
}
