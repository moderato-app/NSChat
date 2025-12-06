import Foundation
import SwiftData

final class ModelContainerProvider {
  static let shared = ModelContainerProvider()
  
  private(set) var container: ModelContainer?
  
  private init() {}
  
  func setContainer(_ container: ModelContainer) {
    self.container = container
  }
}

