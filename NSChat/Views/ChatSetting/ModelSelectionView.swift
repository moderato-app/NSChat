import os
import SwiftData
import SwiftUI

struct ModelSelectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @Query(filter: #Predicate<Provider> { $0.enabled }) private var providers: [Provider]
  @Query private var allModels: [ModelEntity]

  @Bindable var chatOption: ChatOption
  @State private var searchText = ""
  @State private var expandedProviders: Set<PersistentIdentifier> = []
  @State private var favoritesExpanded = true
  @State private var isAddProviderPresented = false

  var body: some View {
    ModelSelectionContent(
      chatOption: chatOption,
      providers: providers,
      allModels: allModels,
      searchText: $searchText,
      expandedProviders: $expandedProviders,
      favoritesExpanded: $favoritesExpanded,
      dismiss: dismiss,
      onAddProvider: {
        isAddProviderPresented = true
      }
    )
    .sheet(isPresented: $isAddProviderPresented) {
      ProviderView(provider: Provider(type: .openAI), mode: .Add)
    }
  }
}

struct ModelSelectionContent: View {
  @Bindable var chatOption: ChatOption
  let providers: [Provider]
  let allModels: [ModelEntity]
  @Binding var searchText: String
  @Binding var expandedProviders: Set<PersistentIdentifier>
  @Binding var favoritesExpanded: Bool
  let dismiss: DismissAction
  let onAddProvider: () -> Void

  private func favoritedModels() -> [ModelEntity] {
    let filtered = allModels.filter { $0.favorited }
    let sorted = ModelEntity.smartSort(filtered)
    return sorted
  }

  private func searchKeywords() -> [String] {
    return parseSearchText(searchText)
  }

  private var filteredModels: [ModelEntity] {
    let keywords = searchKeywords()
    if keywords.isEmpty {
      return allModels
    }
    let filtered = allModels.filter { model in
      let nameMatches = matchesKeywords(text: model.resolvedName, keywords: keywords)
      let idMatches = matchesKeywords(text: model.modelId, keywords: keywords)
      return nameMatches || idMatches
    }
    return filtered
  }

  private func parseSearchText(_ text: String) -> [String] {
    let separators = CharacterSet(charactersIn: " ,")
    let keywords = text.components(separatedBy: separators)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    return keywords
  }

  private func matchesKeywords(text: String, keywords: [String]) -> Bool {
    guard !keywords.isEmpty else { return true }

    let lowercasedText = text.lowercased()
    return keywords.allSatisfy { keyword in
      lowercasedText.contains(keyword.lowercased())
    }
  }

  private var groupedProviders: [(provider: Provider, models: [ModelEntity])] {
    let modelsToGroup: [ModelEntity]
    if searchText.isEmpty {
      modelsToGroup = allModels
    } else {
      modelsToGroup = filteredModels
    }
    return modelsToGroup.groupedByProvider()
  }

  var body: some View {
    ScrollViewReader { proxy in
      List {
        favoritesSection
        providerSections
        emptyStateViews
      }
      .searchable(text: $searchText, prompt: "Search models")
      .navigationTitle("Select Model")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .onAppear {
        expandInitialSections()
        scrollToSelectedModel(proxy: proxy)
      }
    }
  }

  @ViewBuilder
  private var favoritesSection: some View {
    let favorited = favoritedModels()
    if !favorited.isEmpty && searchText.isEmpty {
      DisclosureGroup(
        isExpanded: $favoritesExpanded
      ) {
        ForEach(favorited) { model in
          ModelSelectionRow(
            model: model,
            isSelected: model.id == chatOption.model?.id,
            showProvider: true,
            searchKeywords: searchKeywords()
          ) {
            selectModel(model)
          }
          .id(model.id)
        }
      } label: {
        Text("Favorites").font(.headline)
      }
      .tint(.secondary)
    }
  }

  @ViewBuilder
  private var providerSections: some View {
    ForEach(groupedProviders, id: \.provider.id) { group in
      providerSection(for: group)
    }
  }

  private func providerSection(for group: (provider: Provider, models: [ModelEntity])) -> some View {
    DisclosureGroup(
      isExpanded: providerBinding(for: group.provider.id)
    ) {
      ForEach(group.models) { model in
        ModelSelectionRow(
          model: model,
          isSelected: model.id == chatOption.model?.id,
          showProvider: false,
          searchKeywords: searchKeywords()
        ) {
          selectModel(model)
        }
        .id(model.id)
      }
    } label: {
      HStack {
        Text(group.provider.displayName)
          .font(.headline)
      }
    }
    .tint(.secondary)
  }

  private func providerBinding(for providerId: PersistentIdentifier) -> Binding<Bool> {
    Binding(
      get: { expandedProviders.contains(providerId) },
      set: { isExpanded in
        if isExpanded {
          expandedProviders.insert(providerId)
        } else {
          expandedProviders.remove(providerId)
        }
      }
    )
  }

  @ViewBuilder
  private var emptyStateViews: some View {
    if !searchText.isEmpty && filteredModels.isEmpty {
      ContentUnavailableView.search
    }

    if providers.isEmpty && allModels.isEmpty {
      EmptyProviderCard {
        onAddProvider()
      }
    }
  }

  private func expandInitialSections() {
    guard expandedProviders.isEmpty else { return }

    // Check if selected model exists and is not in favorites
    let favorited = favoritedModels()
    if let selectedModel = chatOption.model,
       !favorited.contains(where: { $0.id == selectedModel.id })
    {
      // Find and expand only the provider containing the selected model
      if let providerGroup = groupedProviders.first(where: { group in
        group.models.contains(where: { $0.id == selectedModel.id })
      }) {
        expandedProviders = [providerGroup.provider.id]
      }
    }
    // Otherwise, all providers remain collapsed (only favorites is expanded)
  }

  private func scrollToSelectedModel(proxy: ScrollViewProxy) {
    guard let selectedModel = chatOption.model else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      withAnimation {
        proxy.scrollTo(selectedModel.id, anchor: .center)
      }
    }
  }

  private func selectModel(_ model: ModelEntity) {
    chatOption.model = model
  }
}

struct ModelSelectionRow: View {
  let model: ModelEntity
  let isSelected: Bool
  let showProvider: Bool
  let searchKeywords: [String]
  let action: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: action) {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            HighlightedText(
              text: model.resolvedName,
              keywords: searchKeywords
            )
            .font(.body)
            .foregroundColor(.primary)

            HStack(spacing: 8) {
              if showProvider {
                Text(model.provider.displayName)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }

              if model.isCustom {
                Label("Custom", systemImage: "wrench")
                  .font(.caption2)
                  .foregroundColor(.blue)
              }
            }
            ContextLengthView(model.inputContextLength, model.outputContextLength)
          }

          Spacer()

          if isSelected {
            Image(systemName: "checkmark")
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button {
        withAnimation {
          model.favorited.toggle()
        }
      } label: {
        Image(systemName: model.favorited ? "star.fill" : "star")
          .foregroundColor(model.favorited ? .yellow : .gray)
      }
      .buttonStyle(.plain)
    }
  }
}

struct HighlightedText: View {
  let text: String
  let keywords: [String]

  var body: some View {
    if keywords.isEmpty {
      Text(text)
    } else {
      Text(attributedString)
    }
  }

  private var attributedString: AttributedString {
    var attributed = AttributedString(text)

    let lowercasedText = text.lowercased()

    for keyword in keywords {
      let lowercasedKeyword = keyword.lowercased()
      var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex

      while let range = lowercasedText.range(of: lowercasedKeyword, options: [], range: searchRange) {
        if let attributedRange = Range(range, in: attributed) {
          attributed[attributedRange].backgroundColor = .yellow.opacity(0.3)
          attributed[attributedRange].font = .body.bold()
        }
        searchRange = range.upperBound..<lowercasedText.endIndex
      }
    }

    return attributed
  }
}
