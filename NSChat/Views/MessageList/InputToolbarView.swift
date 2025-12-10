import Combine
import os
import SwiftData
import SwiftUI
import SystemNotification

struct InputToolbarView: View {
  @Bindable var chatOption: ChatOption
  @Binding var inputText: String
  @Environment(\.modelContext) private var modelContext
  @State private var cachedModels: [ModelEntity] = []
  @State private var cachedProviders: [Provider] = []
  @State private var cachedIsWebSearchEnabled = false
  @State private var cachedIsWebSearchAvaialbe = false
  @EnvironmentObject private var notificationContext: SystemNotificationContext
  @EnvironmentObject private var em: EM

  @State var showingClearButton = false

  private var favoritedModels: [ModelEntity] {
    let filtered = cachedModels.filter { $0.favorited }
    return ModelEntity.smartSort(filtered)
  }

  private var groupedProviders: [(provider: Provider, models: [ModelEntity])] {
    let grouped = cachedModels.groupedByProvider()
      .filter { $0.provider.enabled }
    // Ensure stable sorting by displayName
    return grouped.sorted { $0.provider.displayName < $1.provider.displayName }
  }

  private var selectedModel: ModelEntity? {
    chatOption.model
  }

  var body: some View {
    HStack(spacing: 8) {
      // Clear Button
      if showingClearButton {
        clearButtonContent()
          .transition(.asymmetric(insertion: .scale, removal: .scale).combined(with: .opacity))
      }

      modelPickerContent()

      historyPickerContent()

      if cachedIsWebSearchAvaialbe {
        webSearchContent()
      }

      Spacer()
    }
    .animation(.default, value: chatOption.model)
    .task {
      reloadData()
    }
    .onReceive(em.chatOptionChanged) {
      reloadData()
    }
    .onChange(of: inputText) { _, b in
      withAnimation {
        showingClearButton = !b.isEmpty
      }
    }
  }

  // MARK: - ViewBuilder

  @ViewBuilder
  private func clearButtonContent() -> some View {
    Button(action: {
      inputText = ""
      HapticsService.shared.shake(.light)
    }) {
      ClearIcon(font: .body)
    }
  }

  @ViewBuilder
  private func modelPickerContent() -> some View {
    Menu {
      Button {
        // TODO: Navigate to settings
      } label: {
        Label("More", systemImage: "ellipsis")
      }
      .hidden()

      if !groupedProviders.isEmpty {
        Section("Providers") {
          ForEach(groupedProviders, id: \.provider.id) { group in
            providerMenu(group: group)
          }
        }
      }

      // Favorite models section - always first
      if !favoritedModels.isEmpty {
        Divider()
        Section("Favorites") {
          ForEach(favoritedModels) { model in
            Button {
              chatOption.model = model
              em.chatOptionChanged.send()
            } label: {
              HStack {
                Text(model.resolvedName)
                Spacer()
                if model.id == selectedModel?.id {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        if let model = selectedModel {
          Text(model.resolvedName)
            .lineLimit(1)
        } else {
          Text("Select Model")
            .foregroundStyle(.secondary)
        }
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2)
          .foregroundStyle(selectedModel == nil ? .secondary : .primary)
      }
      .font(.caption)
    }
    .environment(\.menuOrder, .fixed)
    .controlSize(.small)
  }

  @ViewBuilder
  private func providerMenu(group: (provider: Provider, models: [ModelEntity])) -> some View {
    let hasSelectedModel = group.models.contains { $0.id == selectedModel?.id }

    Menu {
      ForEach(group.models) { model in
        Button {
          chatOption.model = model
          em.chatOptionChanged.send()
        } label: {
          Label {
            Text(model.resolvedName)
          } icon: {
            if model.id == selectedModel?.id {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    } label: {
      HStack {
        Text(group.provider.displayName)
        Spacer()
        if hasSelectedModel {
          Image(systemName: "checkmark")
        }
      }
    }
  }

  @ViewBuilder
  private func historyPickerContent() -> some View {
    // History Messages Size Picker
    Picker("History Messages", selection: $chatOption.historyCount) {
      Section("History Messages") {
        ForEach(historyCountChoices.reversed(), id: \.self) { choice in
          Text(choice.lengthString)
            .tag(choice.length)
        }
      }
    }
    .font(.caption)
    .controlSize(.small)
    .if(chatOption.historyCount == HistoryCount.zero.length) {
      $0.tint(.secondary).foregroundStyle(.secondary)
    }
    .if(chatOption.historyCount == HistoryCount.infinite.length) {
      $0.tint(.orange)
    }
  }

  @ViewBuilder
  private func webSearchContent() -> some View {
    Button {
      if let wso = chatOption.webSearchOption {
        wso.enabled.toggle()
      } else {
        let wso = WebSearch()
        wso.enabled = cachedIsWebSearchEnabled
        chatOption.webSearchOption = wso
      }

      cachedIsWebSearchEnabled = chatOption.webSearchOption?.enabled ?? false

      HapticsService.shared.shake(.light)

      SystemNotificationManager.shared.showWebSearchNotification(
        enabled: cachedIsWebSearchEnabled,
        context: notificationContext
      )
    } label: {
      Image(systemName: "globe")
        .foregroundStyle(cachedIsWebSearchEnabled ? Color.accentColor : .secondary)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Helpers

  private func reloadData() {
    cachedIsWebSearchAvaialbe = chatOption.model?.provider.type.isWebSearchAvailable ?? false
    cachedIsWebSearchEnabled = chatOption.webSearchOption?.enabled ?? false
    do {
      let providerDescriptor = FetchDescriptor<Provider>(
        predicate: #Predicate<Provider> { $0.enabled }
      )
      cachedProviders = try modelContext.fetch(providerDescriptor)

      let modelDescriptor = FetchDescriptor<ModelEntity>()
      cachedModels = try modelContext.fetch(modelDescriptor)
    } catch {
      AppLogger.error.error("Failed to fetch toolbar data: \(error.localizedDescription)")
    }
  }
}

#Preview {
  ModelContainerPreview(ModelContainer.preview) {
    VStack {
      Spacer()
      InputToolbarView(chatOption: ChatSample.manyMessages.option, inputText: .constant(""))
        .environmentObject(SystemNotificationContext())
    }
  }
}
