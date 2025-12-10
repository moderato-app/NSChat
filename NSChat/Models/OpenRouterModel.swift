import Foundation
import SwiftData

@Model
final class OpenRouterModel {
  @Attribute(originalName: "modelId") var modelId: String = ""
  @Attribute(originalName: "modelName") var modelName: String?
  @Attribute(originalName: "inputContextLength") var inputContextLength: Int?
  @Attribute(originalName: "outputContextLength") var outputContextLength: Int?
  @Attribute(originalName: "createdAt") var createdAt: Date

  init(
    modelId: String,
    modelName: String? = nil,
    inputContextLength: Int? = nil,
    outputContextLength: Int? = nil,
  ) {
    self.modelId = modelId
    self.modelName = modelName
    self.inputContextLength = inputContextLength
    self.outputContextLength = outputContextLength
    self.createdAt = .now
  }
}
