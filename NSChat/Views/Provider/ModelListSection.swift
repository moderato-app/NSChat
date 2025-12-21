import os
import SwiftData
import SwiftUI

struct ModelListSection: View {
  @Bindable var provider: Provider
  @Binding var searchText: String

  @Binding var modelToEdit: ModelEntity?
  @Binding var showingAddModel: Bool
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var em: EM
  @State var fetchStatus: ProviderFetchStatus = .idle

  private var filteredModels: [ModelEntity] {
    if searchText.isEmpty {
      return ModelEntity.versionSort(provider.models)
    }
    let filtered = provider.models.filter { model in
      model.resolvedName.localizedStandardContains(searchText)
        || model.modelId.localizedStandardContains(searchText)
    }
    return ModelEntity.versionSort(filtered)
  }

  var body: some View {
    Section {
      if fetchStatus != .idle {
        fetchStatusRow()
      }

      if filteredModels.isEmpty && searchText.isEmpty && fetchStatus == .idle {
        VStack {
          ContentUnavailableView {
            Label("No Models", systemImage: "cube.transparent")
          } description: {
            if !provider.apiKey.isMeaningful {
              Text("Fetch models from the provider or add custom models")
            }
          }
          if provider.apiKey.isMeaningful {
            Button {
              fetchModels()
            } label: {
              HStack {
                Image(systemName: "arrow.clockwise")
                  .backgroundStyle(.foreground)
                Text("Fetch Models")
              }
            }
            .buttonStyle(.borderedProminent)
            .disabled(fetchStatus == .fetching)
            .padding(.bottom, 10)
          }
        }
      } else {
        ForEach(filteredModels) { model in
          ModelRow(
            model: model,
            onEditButtonPressed: { modelToEdit = model },
            onDelete: onDelete
          )
        }
      }
    } header: {
      HStack {
        Text("Models (\(provider.models.count))")
        Spacer()
        HStack(spacing: 12) {
          if fetchStatus != .fetching {
            Button {
              fetchModels()
            } label: {
              Image(systemName: "arrow.clockwise")
            }
            .font(.caption)
          }

          Button {
            showingAddModel = true
          } label: {
            Image(systemName: "plus")
          }
          .font(.caption)
        }
      }
    }
  }

  @ViewBuilder
  private func fetchStatusRow() -> some View {
    HStack {
      switch fetchStatus {
      case .idle:
        EmptyView()
      case .fetching:
        ProgressView()
        Text("Fetching models…")
      case .success(let count):
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.green)
        Text("Fetched \(count) model\(count == 1 ? "" : "s")")
      case .error(let message):
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundColor(.orange)
        Text(message)
          .font(.caption)
      }
    }
  }

  func fetchModels() {
    guard fetchStatus != .fetching else { return }

    let apiKey = provider.apiKey
    if apiKey.isEmpty {
      fetchStatus = .error("API Key is required")
      return
    }

    fetchStatus = .fetching

    Task {
      do {
        let service = ProviderModelFetchService(modelContext: modelContext)
        let modelInfos = try await service.fetchModels(
          providerType: provider.type,
          apiKey: apiKey,
          endpoint: provider.endpoint.isEmpty ? nil : provider.endpoint
        )

        await MainActor.run {
          fetchStatus = .success(modelInfos.count)
          provider.syncModels(with: modelInfos, in: modelContext)
          AppLogger.data.info("Fetched \(modelInfos.count) models for \(provider.displayName)")
        }
      } catch {
        await MainActor.run {
          fetchStatus = .error(error.localizedDescription)

          AppLogger.logError(
            .from(
              error: error,
              operation: "Fetch models",
              component: "ModelListSection"
            ))
        }
      }
    }
  }

  func onDelete(model: ModelEntity) {
    do {
      try modelContext.deleteModel(model)
    } catch {
      AppLogger.logError(
        .from(
          error: error,
          operation: "Delete model",
          component: "ModelListSection"
        ))
    }
  }
}

enum ProviderFetchStatus: Equatable {
  case idle
  case fetching
  case success(Int)
  case error(String)

  static func == (lhs: ProviderFetchStatus, rhs: ProviderFetchStatus) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle), (.fetching, .fetching):
      return true
    case (.success(let l), .success(let r)):
      return l == r
    case (.error(let l), .error(let r)):
      return l == r
    default:
      return false
    }
  }
}

struct ModelRow: View {
  @Bindable var model: ModelEntity
  let onEditButtonPressed: () -> Void
  let onDelete: (ModelEntity) -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(model.resolvedName)
          .font(.body)

        HStack(spacing: 8) {
          ContextLengthView(model.inputContextLength, model.outputContextLength)
        }
      }

      Spacer()

      if model.isCustom {
        Image(systemName: "wrench")
          .foregroundColor(.primary)
      }

      if model.favorited {
        Button {
          model.favorited.toggle()
        } label: {
          Image(systemName: "star.fill")
            .foregroundColor(.yellow)
        }
        .buttonStyle(.plain)
      }
    }
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      Button {
        withAnimation {
          model.favorited.toggle()
        }
      } label: {
        Label(
          model.favorited ? "Unfavorite" : "Favorite",
          systemImage: model.favorited ? "star.slash.fill" : "star.fill"
        )
      }
      .tint(.yellow)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive) {
        onDelete(model)
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
    .contextMenu {
      Text(model.modelId)

      Divider()

      if model.isCustom {
        Button {
          onEditButtonPressed()
        } label: {
          Label("Edit", systemImage: "pencil")
        }
      }

      Button {
        withAnimation {
          model.favorited.toggle()
        }
      } label: {
        Label(
          model.favorited ? "Unfavorite" : "Favorite",
          systemImage: model.favorited ? "star.slash" : "star"
        )
      }

      Divider()

      Button(role: .destructive) {
        onDelete(model)
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }
}
