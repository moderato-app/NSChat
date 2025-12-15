import Foundation
import os
import SwiftData

extension ModelContext {
  func createNewChat() throws -> Chat {
    let model = try chooseModel()
    let option = ChatOption(
      model: model,
      contextLength: Pref.shared.newChatPrefHistoryMessageCount,
      webSearchOption: WebSearch(
        enabled: Pref.shared.newChatPrefWebSearchEnabled,
        contextSize: Pref.shared.newChatPrefWebSearchContextSize
      )
    )
    let chat = Chat(name: ChatConstants.DEFAULT_CHAT_NAME, option: option)

    return chat
  }

  func chooseModel() throws -> ModelEntity? {
    // Find model of the latest chat
    let predicate = #Predicate<Chat> { $0.option.model != nil }
    let fetcher = FetchDescriptor<Chat>(
      predicate: predicate,
      sortBy: [SortDescriptor(\Chat.updatedAt, order: .reverse)],
      fetchLimit: 10
    )
    if let chat = try? fetch(fetcher).first {
      // Find the latest chat with model
      if let m = chat.option.model {
        return m
      }
    }

    // Find the model with the most chats
    let fetcher2 = FetchDescriptor<ChatOption>()
    let opts = try? fetch(fetcher2)
    if let options = opts {
      let models = options.compactMap { $0.model }
      let grouped = Dictionary(grouping: models) { $0.persistentModelID }
      if let mostUsed = grouped.max(by: { $0.value.count < $1.value.count }) {
        if let m = mostUsed.value.first {
          return m
        }
      }
    }

    let fetcher3 = FetchDescriptor<ModelEntity>()
    if let allModels = try? fetch(fetcher3) {
      let sortedModels = ModelEntity.smartSort(allModels)
      for m in sortedModels {
        if m.provider.type.recommendedModels.contains(m.modelId) {
          return m
        }
      }
      return allModels.first
    }

    return nil
  }

  func getMessage(messageId: PersistentIdentifier) -> Message? {
    let predicate = #Predicate<Message> { $0.persistentModelID == messageId }
    let fetcher = FetchDescriptor<Message>(predicate: predicate, fetchLimit: 1)
    do {
      let message = try fetch(fetcher).first
      return message
    } catch {
      AppLogger.data.error("error query message, messageId: \(String(describing: messageId)), err: \(error.localizedDescription)")
      return nil
    }
  }

  func recentMessgagesEarlyOnTop(chatId: PersistentIdentifier, limit: Int) -> [Message] {
    let predicate = #Predicate<Message> { msg in
      msg.chat?.persistentModelID == chatId
    }
    var fetchDescriptor = FetchDescriptor<Message>(predicate: predicate, sortBy: [SortDescriptor(\Message.createdAt, order: .reverse)])
    fetchDescriptor.fetchLimit = limit
    return try! fetch(fetchDescriptor).sorted()
  }

  func findPromptById(promptId: PersistentIdentifier) -> Prompt? {
    let predicate = #Predicate<Prompt> { prompt in
      prompt.persistentModelID == promptId
    }
    let fetchDescriptor = FetchDescriptor<Prompt>(predicate: predicate)
    return try! fetch(fetchDescriptor).first
  }

  func promptCount() -> Int {
    let descriptor = FetchDescriptor<Prompt>(
      predicate: #Predicate { !$0.preset }
    )
    return (try? fetchCount(descriptor)) ?? 0
  }

  func nextPromptOrder() -> Int {
    let fetchDescriptor = FetchDescriptor<Prompt>(sortBy: [SortDescriptor(\Prompt.order, order: .reverse)], fetchLimit: 1)
    if let order = try! fetch(fetchDescriptor).first?.order {
      return order + 1
    } else {
      return 0
    }
  }

  func clearAll<T>(_ model: T.Type) where T: PersistentModel {
    do {
      let descriptor = FetchDescriptor<T>()
      if let chats = try? fetch(descriptor) {
        for chat in chats {
          delete(chat)
        }
      }
    }
  }

  func clearAllModels() {
    // Clear all models defined in allSchema (see Container.swift)
    // Note: Must manually list types as Schema.Entity cannot be directly converted to T.Type
    clearAll(Chat.self)
    clearAll(ChatOption.self)
    clearAll(WebSearch.self)
    clearAll(Prompt.self)
    clearAll(PromptMessage.self)
    clearAll(Provider.self)
    clearAll(ModelEntity.self)
    clearAll(UsedModel.self)
  }

  func removePresetPrompts() throws {
    try delete(model: Prompt.self, where: #Predicate<Prompt> { $0.preset })
  }

  func deleteModel(_ model: ModelEntity) throws {
    // Find all ChatOptions using this model
    // Use the relationship from ModelEntity to find ChatOptions
    let chatOptions = model.chatOptions

    // Set model to nil for all ChatOptions
    for option in chatOptions {
      option.model = nil
    }

    // Remove model from provider's models array
    model.provider.models.removeAll(where: { $0 == model })

    // Delete the model
    delete(model)

    AppLogger.data.info("Deleted model: \(model.modelId), cleared \(chatOptions.count) chat options")
  }

  func deleteProvider(_ provider: Provider) throws {
    // Find all models of this provider
    let models = provider.models
    var totalClearedOptions = 0

    // For each model, clear all ChatOptions that use it
    for model in models {
      let chatOptions = model.chatOptions
      for option in chatOptions {
        option.model = nil
      }
      totalClearedOptions += chatOptions.count
    }

    // Delete the provider (this will cascade delete all models)
    delete(provider)

    AppLogger.data.info("Deleted provider: \(provider.displayName), cleared \(totalClearedOptions) chat options from \(models.count) models")
  }
}
