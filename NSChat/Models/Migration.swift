import Foundation
import os
import SwiftData

func migrate(_ modelContext: ModelContext) throws {
  try? fillData(modelContext)
  try? migrateToProviderModel(modelContext)

  try? modelContext.save()
}

private func fillData(_ modelContext: ModelContext) throws {
  if !Pref.shared.fillDataRecordPrompts {
    try fillPrompts(modelContext, save: false)
    Pref.shared.fillDataRecordPrompts = true
  }
}

func fillPrompts(_ modelContext: ModelContext, save: Bool) throws {
  let descriptor = FetchDescriptor<Prompt>(
    predicate: #Predicate { !$0.preset }
  )
  let count = (try? modelContext.fetchCount(descriptor)) ?? 0

  let english = PromptSample.english()

  english.prompts.reIndex()

  for p in english.prompts {
    p.order += count
    modelContext.insert(p)
    p.messages.reIndex()
  }

  modelContext.insert(PromptSample.userDefault)

  if save {
    try? modelContext.save()
  }
}

func addPreviewData(_ modelContext: ModelContext) throws {
  for c in ChatSample.previewChats {
    modelContext.insert(c)
  }
  AppLogger.data.info("add preview data: \(ChatSample.previewChats.count) chats")
  try? modelContext.save()
}

func migrateToProviderModel(_ modelContext: ModelContext) throws {
  let pref = Pref.shared

  let apiKey = pref.gptApiKey
  let prividers = try modelContext.fetch(FetchDescriptor<Provider>())

  guard prividers.isEmpty, apiKey != "" else {
    AppLogger.data.info("Already migrated to Provider model")
    return
  }
  defer { pref.gptApiKey = "" }

  AppLogger.data.info("Starting migration to Provider model")

  let provider = Provider(type: .openAI, apiKey: apiKey, enabled: true)
  if pref.gptEnableEndpoint {
    provider.endpoint = pref.gptEndpoint
  }
  modelContext.insert(provider)

  let models = modelsToAdd(provider: provider)

  for model in models {
    modelContext.insert(model)
  }

  AppLogger.data.info("Successfully migrated \(models.count) models to Provider model")

  let chats = try modelContext.fetch(FetchDescriptor<Chat>())
  for chat in chats {
    chat.option.webSearchOption = WebSearch(enabled: false, contextSize: .low)

    let modelId = chat.option.oldModel
    if modelId.isEmpty {
      continue
    }
    if let model = models.first(where: { $0.modelId == modelId }) {
      model.favorited = true
      chat.option.model = model
    }
  }
}

func modelsToAdd(provider: Provider) -> [ModelEntity] {
  return [
    ModelEntity(provider: provider, modelId: "gpt-4-0613", modelName: "GPT-4 0613"),
    ModelEntity(provider: provider, modelId: "gpt-4", modelName: "GPT-4"),
    ModelEntity(provider: provider, modelId: "gpt-3.5-turbo", modelName: "GPT-3.5 Turbo"),
    ModelEntity(provider: provider, modelId: "gpt-4-0314", modelName: "GPT-4 0314"),
    ModelEntity(provider: provider, modelId: "gpt-5.1-codex-mini", modelName: "GPT-5.1 Codex Mini"),
    ModelEntity(provider: provider, modelId: "gpt-5.1-chat-latest", modelName: "GPT-5.1 Chat Latest"),
    ModelEntity(provider: provider, modelId: "gpt-5.1-2025-11-13", modelName: "GPT-5.1 2025-11-13"),
    ModelEntity(provider: provider, modelId: "gpt-5.1", modelName: "GPT-5.1", favorited: true),
    ModelEntity(provider: provider, modelId: "gpt-5.1-codex", modelName: "GPT-5.1 Codex"),
    ModelEntity(provider: provider, modelId: "davinci-002", modelName: "Davinci 002"),
    ModelEntity(provider: provider, modelId: "babbage-002", modelName: "Babbage 002"),
    ModelEntity(provider: provider, modelId: "gpt-3.5-turbo-instruct", modelName: "GPT-3.5 Turbo Instruct"),
    ModelEntity(provider: provider, modelId: "gpt-3.5-turbo-instruct-0914", modelName: "GPT-3.5 Turbo Instruct 0914"),
    ModelEntity(provider: provider, modelId: "dall-e-3", modelName: "DALL-E 3"),
    ModelEntity(provider: provider, modelId: "dall-e-2", modelName: "DALL-E 2"),
    ModelEntity(provider: provider, modelId: "gpt-4-1106-preview", modelName: "GPT-4 1106 Preview"),
    ModelEntity(provider: provider, modelId: "gpt-3.5-turbo-1106", modelName: "GPT-3.5 Turbo 1106"),
    ModelEntity(provider: provider, modelId: "tts-1-hd", modelName: "TTS-1 HD"),
    ModelEntity(provider: provider, modelId: "tts-1-1106", modelName: "TTS-1 1106"),
    ModelEntity(provider: provider, modelId: "tts-1-hd-1106", modelName: "TTS-1 HD 1106"),
    ModelEntity(provider: provider, modelId: "text-embedding-3-small", modelName: "Text Embedding 3 Small"),
    ModelEntity(provider: provider, modelId: "text-embedding-3-large", modelName: "Text Embedding 3 Large"),
    ModelEntity(provider: provider, modelId: "gpt-4-0125-preview", modelName: "GPT-4 0125 Preview"),
    ModelEntity(provider: provider, modelId: "gpt-4-turbo-preview", modelName: "GPT-4 Turbo Preview"),
    ModelEntity(provider: provider, modelId: "gpt-3.5-turbo-0125", modelName: "GPT-3.5 Turbo 0125"),
    ModelEntity(provider: provider, modelId: "gpt-4-turbo", modelName: "GPT-4 Turbo"),
    ModelEntity(provider: provider, modelId: "gpt-4-turbo-2024-04-09", modelName: "GPT-4 Turbo 2024-04-09"),
    ModelEntity(provider: provider, modelId: "gpt-4o", modelName: "GPT-4o"),
    ModelEntity(provider: provider, modelId: "gpt-4o-2024-05-13", modelName: "GPT-4o 2024-05-13"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-2024-07-18", modelName: "GPT-4o Mini 2024-07-18"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini", modelName: "GPT-4o Mini"),
    ModelEntity(provider: provider, modelId: "gpt-4o-2024-08-06", modelName: "GPT-4o 2024-08-06"),
    ModelEntity(provider: provider, modelId: "chatgpt-4o-latest", modelName: "ChatGPT-4o Latest"),
    ModelEntity(provider: provider, modelId: "gpt-4o-realtime-preview-2024-10-01", modelName: "GPT-4o Realtime Preview 2024-10-01"),
    ModelEntity(provider: provider, modelId: "gpt-4o-audio-preview-2024-10-01", modelName: "GPT-4o Audio Preview 2024-10-01"),
    ModelEntity(provider: provider, modelId: "gpt-4o-audio-preview", modelName: "GPT-4o Audio Preview"),
    ModelEntity(provider: provider, modelId: "gpt-4o-realtime-preview", modelName: "GPT-4o Realtime Preview"),
    ModelEntity(provider: provider, modelId: "omni-moderation-latest", modelName: "Omni Moderation Latest"),
    ModelEntity(provider: provider, modelId: "omni-moderation-2024-09-26", modelName: "Omni Moderation 2024-09-26"),
    ModelEntity(provider: provider, modelId: "gpt-4o-realtime-preview-2024-12-17", modelName: "GPT-4o Realtime Preview 2024-12-17"),
    ModelEntity(provider: provider, modelId: "gpt-4o-audio-preview-2024-12-17", modelName: "GPT-4o Audio Preview 2024-12-17"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-realtime-preview-2024-12-17", modelName: "GPT-4o Mini Realtime Preview 2024-12-17"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-audio-preview-2024-12-17", modelName: "GPT-4o Mini Audio Preview 2024-12-17"),
    ModelEntity(provider: provider, modelId: "o1-2024-12-17", modelName: "O1 2024-12-17"),
    ModelEntity(provider: provider, modelId: "o1", modelName: "O1"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-realtime-preview", modelName: "GPT-4o Mini Realtime Preview"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-audio-preview", modelName: "GPT-4o Mini Audio Preview"),
    ModelEntity(provider: provider, modelId: "o3-mini", modelName: "O3 Mini"),
    ModelEntity(provider: provider, modelId: "o3-mini-2025-01-31", modelName: "O3 Mini 2025-01-31"),
    ModelEntity(provider: provider, modelId: "gpt-4o-2024-11-20", modelName: "GPT-4o 2024-11-20"),
    ModelEntity(provider: provider, modelId: "gpt-4o-search-preview-2025-03-11", modelName: "GPT-4o Search Preview 2025-03-11"),
    ModelEntity(provider: provider, modelId: "gpt-4o-search-preview", modelName: "GPT-4o Search Preview"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-search-preview-2025-03-11", modelName: "GPT-4o Mini Search Preview 2025-03-11"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-search-preview", modelName: "GPT-4o Mini Search Preview"),
    ModelEntity(provider: provider, modelId: "gpt-4o-transcribe", modelName: "GPT-4o Transcribe"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-transcribe", modelName: "GPT-4o Mini Transcribe"),
    ModelEntity(provider: provider, modelId: "o1-pro-2025-03-19", modelName: "O1 Pro 2025-03-19"),
    ModelEntity(provider: provider, modelId: "o1-pro", modelName: "O1 Pro"),
    ModelEntity(provider: provider, modelId: "gpt-4o-mini-tts", modelName: "GPT-4o Mini TTS"),
    ModelEntity(provider: provider, modelId: "o3-2025-04-16", modelName: "O3 2025-04-16"),
    ModelEntity(provider: provider, modelId: "o4-mini-2025-04-16", modelName: "O4 Mini 2025-04-16"),
    ModelEntity(provider: provider, modelId: "o3", modelName: "O3"),
    ModelEntity(provider: provider, modelId: "o4-mini", modelName: "O4 Mini"),
    ModelEntity(provider: provider, modelId: "gpt-4.1-2025-04-14", modelName: "GPT-4.1 2025-04-14"),
    ModelEntity(provider: provider, modelId: "gpt-4.1", modelName: "GPT-4.1"),
    ModelEntity(provider: provider, modelId: "gpt-4.1-mini-2025-04-14", modelName: "GPT-4.1 Mini 2025-04-14"),
    ModelEntity(provider: provider, modelId: "gpt-4.1-mini", modelName: "GPT-4.1 Mini"),
    ModelEntity(provider: provider, modelId: "gpt-4.1-nano-2025-04-14", modelName: "GPT-4.1 Nano 2025-04-14"),
    ModelEntity(provider: provider, modelId: "gpt-4.1-nano", modelName: "GPT-4.1 Nano"),
    ModelEntity(provider: provider, modelId: "gpt-image-1", modelName: "GPT Image 1"),
    ModelEntity(provider: provider, modelId: "gpt-4o-realtime-preview-2025-06-03", modelName: "GPT-4o Realtime Preview 2025-06-03"),
    ModelEntity(provider: provider, modelId: "gpt-4o-audio-preview-2025-06-03", modelName: "GPT-4o Audio Preview 2025-06-03"),
    ModelEntity(provider: provider, modelId: "gpt-4o-transcribe-diarize", modelName: "GPT-4o Transcribe Diarize"),
    ModelEntity(provider: provider, modelId: "gpt-5-chat-latest", modelName: "GPT-5 Chat Latest"),
    ModelEntity(provider: provider, modelId: "gpt-5-2025-08-07", modelName: "GPT-5 2025-08-07"),
    ModelEntity(provider: provider, modelId: "gpt-5", modelName: "GPT-5"),
    ModelEntity(provider: provider, modelId: "gpt-5-mini-2025-08-07", modelName: "GPT-5 Mini 2025-08-07"),
    ModelEntity(provider: provider, modelId: "gpt-5-mini", modelName: "GPT-5 Mini", favorited: true),
    ModelEntity(provider: provider, modelId: "gpt-5-nano-2025-08-07", modelName: "GPT-5 Nano 2025-08-07"),
    ModelEntity(provider: provider, modelId: "gpt-5-nano", modelName: "GPT-5 Nano"),
    ModelEntity(provider: provider, modelId: "gpt-audio-2025-08-28", modelName: "GPT Audio 2025-08-28"),
    ModelEntity(provider: provider, modelId: "gpt-realtime", modelName: "GPT Realtime"),
    ModelEntity(provider: provider, modelId: "gpt-realtime-2025-08-28", modelName: "GPT Realtime 2025-08-28"),
    ModelEntity(provider: provider, modelId: "gpt-audio", modelName: "GPT Audio"),
    ModelEntity(provider: provider, modelId: "gpt-5-codex", modelName: "GPT-5 Codex"),
    ModelEntity(provider: provider, modelId: "gpt-image-1-mini", modelName: "GPT Image 1 Mini"),
    ModelEntity(provider: provider, modelId: "gpt-5-pro-2025-10-06", modelName: "GPT-5 Pro 2025-10-06"),
    ModelEntity(provider: provider, modelId: "gpt-5-pro", modelName: "GPT-5 Pro"),
    ModelEntity(provider: provider, modelId: "gpt-audio-mini", modelName: "GPT Audio Mini"),
    ModelEntity(provider: provider, modelId: "gpt-audio-mini-2025-10-06", modelName: "GPT Audio Mini 2025-10-06"),
    ModelEntity(provider: provider, modelId: "gpt-5-search-api", modelName: "GPT-5 Search API"),
    ModelEntity(provider: provider, modelId: "gpt-realtime-mini", modelName: "GPT Realtime Mini"),
    ModelEntity(provider: provider, modelId: "gpt-realtime-mini-2025-10-06", modelName: "GPT Realtime Mini 2025-10-06"),
    ModelEntity(provider: provider, modelId: "sora-2", modelName: "Sora 2"),
    ModelEntity(provider: provider, modelId: "sora-2-pro", modelName: "Sora 2 Pro"),
    ModelEntity(provider: provider, modelId: "gpt-5-search-api-2025-10-14", modelName: "GPT-5 Search API 2025-10-14"),
    ModelEntity(provider: provider, modelId: "gpt-3.5-turbo-16k", modelName: "GPT-3.5 Turbo 16k"),
    ModelEntity(provider: provider, modelId: "tts-1", modelName: "TTS-1"),
    ModelEntity(provider: provider, modelId: "whisper-1", modelName: "Whisper 1"),
    ModelEntity(provider: provider, modelId: "text-embedding-ada-002", modelName: "Text Embedding Ada 002"),
  ]
}
