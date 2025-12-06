import os
import SwiftData
import SwiftUI

enum ProviderViewMode {
  case Add, Edit
}

struct ProviderView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @Bindable var provider: Provider
  let mode: ProviderViewMode

  @State private var searchText = ""
  @State private var modelToEdit: ModelEntity?
  @State private var showingAddModel = false

  var body: some View {
    CondNavigationStack(mode == .Add) {
      list
    }
  }

  @ViewBuilder
  var list: some View {
    List {
      ProviderConfigurationForm(
        provider: provider,
        mode: mode
      )

      ModelListSection(
        provider: provider,
        searchText: $searchText,
        modelToEdit: $modelToEdit,
        showingAddModel: $showingAddModel
      )
    }
    .animation(.default, value: provider.models.map { $0.persistentModelID })
    .searchable(text: $searchText, prompt: "Search models")
    .navigationBarTitleDisplayMode(.inline)
    .navigationTitle(title)
    .toolbar {
      if mode == .Add {
        toolbar
      }
    }
    .onDisappear {
      if mode == .Edit {
        try? modelContext.save()
      }
    }
    .sheet(isPresented: $showingAddModel) {
      AddCustomModelView(provider: provider)
    }
    .sheet(item: $modelToEdit) { model in
      EditModelView(model: model)
    }
  }

  var title: String {
    switch mode {
    case .Add:
      return "Add Provider"
    case .Edit:
      return provider.displayName
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button("Cancel") {
        dismiss()
      }
    }

    ToolbarItem(placement: .confirmationAction) {
      Button("Save") {
        saveProvider()
      }
      .disabled(provider.apiKey.isEmpty)
    }
  }

  private func saveProvider() {
    modelContext.insert(provider)
    AppLogger.data.info("Added new provider: \(provider.displayName) with \(provider.models.count) models")
    
    // If provider has no models, try to fetch them
    if provider.models.isEmpty {
      Task {
        await fetchModelsForProvider()
      }
    }
    
    dismiss()
  }
  
  private func fetchModelsForProvider() async {
    guard !provider.apiKey.isEmpty else {
      AppLogger.data.info("Skipping model fetch for \(provider.displayName): API key is empty")
      return
    }
    
    // First, try to fetch models using the provider's own fetcher
    var fetchedModels: [ModelInfo] = []
    
    do {
      let fetcher = provider.type.createFetcher()
      fetchedModels = try await fetcher.fetchModels(
        apiKey: provider.apiKey,
        endpoint: provider.endpoint.isEmpty ? nil : provider.endpoint
      )
      AppLogger.data.info("Fetched \(fetchedModels.count) models from \(provider.displayName) API")
    } catch {
      AppLogger.logError(.from(
        error: error,
        operation: "Fetch models from provider",
        component: "ProviderView"
      ))
    }
    
    // If no models were fetched, try OpenRouter fallback
    if fetchedModels.isEmpty, let prefix = provider.type.openRouterPrefix {
      // First, try to get OpenRouter models from database
      let descriptor = FetchDescriptor<OpenRouterModel>()
      let dbModels = try? modelContext.fetch(descriptor)
      
      if let dbModels = dbModels, !dbModels.isEmpty {
        // Convert database models to ModelInfo and filter by prefix
        let allOpenRouterModels = dbModels.map { model in
          ModelInfo(
            id: model.modelId,
            name: model.modelName,
            inputContextLength: model.inputContextLength,
            outputContextLength: model.outputContextLength
          )
        }
        
        let filteredModels = allOpenRouterModels
          .filter { modelInfo in
            modelInfo.id.hasPrefix("\(prefix)/")
          }
          .map { modelInfo in
            // Remove prefix from model ID
            let prefixWithSlash = "\(prefix)/"
            let modelIdWithoutPrefix = modelInfo.id.hasPrefix(prefixWithSlash)
              ? String(modelInfo.id.dropFirst(prefixWithSlash.count))
              : modelInfo.id
            return ModelInfo(
              id: modelIdWithoutPrefix,
              name: modelInfo.name,
              inputContextLength: modelInfo.inputContextLength,
              outputContextLength: modelInfo.outputContextLength
            )
          }
        
        if !filteredModels.isEmpty {
          fetchedModels = filteredModels
          AppLogger.data.info("Fetched \(filteredModels.count) models from database filtered by prefix '\(prefix)/'")
        }
      }
      
      // If database has no models, fetch from OpenRouter API
      if fetchedModels.isEmpty {
        var allOpenRouterModels: [ModelInfo] = []
        
        // Try with empty API key first (some endpoints allow public access)
        do {
          let openRouterFetcher = OpenRouterModelFetcher()
          allOpenRouterModels = try await openRouterFetcher.fetchModels(
            apiKey: "",
            endpoint: nil
          )
          AppLogger.data.info("Fetched OpenRouter models with public access")
        } catch {
          // If that fails, try with provider's API key
          do {
            let openRouterFetcher = OpenRouterModelFetcher()
            allOpenRouterModels = try await openRouterFetcher.fetchModels(
              apiKey: provider.apiKey,
              endpoint: nil
            )
            AppLogger.data.info("Fetched OpenRouter models with provider API key")
          } catch {
            AppLogger.logError(.from(
              error: error,
              operation: "Fetch models from OpenRouter",
              component: "ProviderView"
            ))
          }
        }
        
        // Filter by prefix and remove prefix from model ID
        if !allOpenRouterModels.isEmpty {
          let prefixWithSlash = "\(prefix)/"
          let filteredModels = allOpenRouterModels
            .filter { modelInfo in
              modelInfo.id.hasPrefix(prefixWithSlash)
            }
            .map { modelInfo in
              // Remove prefix from model ID
              let modelIdWithoutPrefix = String(modelInfo.id.dropFirst(prefixWithSlash.count))
              return ModelInfo(
                id: modelIdWithoutPrefix,
                name: modelInfo.name,
                inputContextLength: modelInfo.inputContextLength,
                outputContextLength: modelInfo.outputContextLength
              )
            }
          
          fetchedModels = filteredModels
          AppLogger.data.info("Fetched \(filteredModels.count) models from OpenRouter API filtered by prefix '\(prefix)/'")
        }
      }
    }
    
    // Update provider's models if we fetched any
    if !fetchedModels.isEmpty {
      await MainActor.run {
        updateProviderModels(with: fetchedModels)
      }
    }
  }
  
  private func updateProviderModels(with modelInfos: [ModelInfo]) {
    var toAdd: [ModelEntity] = []
    
    for modelInfo in modelInfos {
      // Check if model already exists
      let exists = provider.models.contains { $0.modelId == modelInfo.id }
      if !exists {
        let newModel = ModelEntity(
          provider: provider,
          modelId: modelInfo.id,
          modelName: modelInfo.name,
          inputContextLength: modelInfo.inputContextLength,
          outputContextLength: modelInfo.outputContextLength
        )
        toAdd.append(newModel)
      }
    }
    
    if !toAdd.isEmpty {
      provider.models.append(contentsOf: toAdd)
      AppLogger.data.info("Added \(toAdd.count) models to provider \(provider.displayName)")
      
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
}
