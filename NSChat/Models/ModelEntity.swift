import Foundation
import SwiftData

@Model
final class ModelEntity {
  @Attribute(originalName: "modelId") var modelId: String = ""
  @Attribute(originalName: "modelName") var modelName: String?
  @Attribute(originalName: "inputContextLength") var inputContextLength: Int?
  @Attribute(originalName: "outputContextLength") var outputContextLength: Int?
  @Attribute(originalName: "favorited") var favorited: Bool
  @Attribute(originalName: "isCustom") var isCustom: Bool
  @Attribute(originalName: "createdAt") var createdAt: Date
  @Relationship(originalName: "provider")
  var provider: Provider
  @Relationship(deleteRule: .nullify, originalName: "chatOptions")
  var chatOptions: [ChatOption]
  @Relationship(deleteRule: .cascade, originalName: "usedModels", inverse: \UsedModel.model)
  var usedModels: [UsedModel]

  init(
    provider: Provider,
    modelId: String,
    modelName: String? = nil,
    inputContextLength: Int? = nil,
    outputContextLength: Int? = nil,
    favorited: Bool = false,
    isCustom: Bool = false,
  ) {
    self.provider = provider
    self.modelId = modelId
    self.modelName = modelName
    self.inputContextLength = inputContextLength
    self.outputContextLength = outputContextLength
    self.favorited = favorited
    self.isCustom = isCustom
    self.createdAt = .now
    self.chatOptions = []
    self.usedModels = []
  }

  var resolvedName: String {
    modelName ?? modelId
  }
}

extension Array where Element == ModelEntity {
  func groupedByProvider() -> [(provider: Provider, models: [ModelEntity])] {
    let grouped = Dictionary(grouping: self) { $0.provider }
    return grouped.compactMap { provider, value in
      let sortedModels = ModelEntity.versionSort(value)
      return (provider: provider, models: sortedModels)
    }.sorted { $0.provider.displayName < $1.provider.displayName }
  }
}
