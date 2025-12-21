import Combine
import SwiftData

class EM: ObservableObject {
  static let shared = EM()
  let messageEvent = PassthroughSubject<MessageEventType, Never>()

  let reUseTextEvent = PassthroughSubject<String, Never>()

  let chatOptionPromptChangeEvent = PassthroughSubject<PersistentIdentifier?, Never>()

  let messageCountChange = PassthroughSubject<PersistentIdentifier, Never>()

  let chatOptionChanged = PassthroughSubject<Void, Never>()
}

enum MessageEventType {
  case new, eof, err, countChanged
}
