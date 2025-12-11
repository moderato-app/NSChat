import SwiftData
import SwiftUI
import os

struct ProviderListView: View {
  @State var searchString = ""

  var body: some View {
    ListProvider(searchString: searchString)
      .searchable(text: $searchString)
      .animation(.easeInOut, value: searchString)
  }
}

private struct ListProvider: View {
  @Query(sort: \Provider.createdAt, order: .reverse) private var allProviders: [Provider]

  @State private var isAddProviderPresented = false
  @State private var isDeleteProviderConfirmPresented: Bool = false
  @State private var providersToDelete: [Provider] = []

  @Environment(\.modelContext) private var modelContext

  let searchString: String

  init(searchString: String) {
    self.searchString = searchString
  }

  private var providers: [Provider] {
    if searchString.isEmpty {
      return allProviders
    }
    return allProviders.filter { provider in
      provider.displayName.localizedStandardContains(searchString)
    }
  }

  var body: some View {
    List {
      if providers.isEmpty {
        Section {
          EmptyProviderCard {
            isAddProviderPresented = true
          }
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }
      } else {
        ForEach(providers) { provider in
          NavigationLink {
            ProviderView(provider: provider, mode: .Edit)
          } label: {
            ProviderRow(provider: provider)
          }
        }
        .onDelete(perform: deleteProviders)

        Button {
          isAddProviderPresented = true
        } label: {
          HStack {
            Image(systemName: "plus.circle.fill")
            Text("Add Provider")
          }
        }
        .foregroundStyle(.tint)
      }
    }
    .listStyle(.plain)
    .animation(.default, value: providers.count)
    .navigationBarTitle("Providers")
    .sheet(isPresented: $isAddProviderPresented) {
      let provider = Provider(type: .openAI)
      ProviderView(provider: provider, mode: .Add)
    }
    .confirmationDialog(
      providersToDelete.count == 1
        ? (providersToDelete.first?.displayName ?? "Provider")
        : "Delete \(providersToDelete.count) Providers",
      isPresented: $isDeleteProviderConfirmPresented,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        for provider in providersToDelete {
          do {
            try modelContext.deleteProvider(provider)
            try modelContext.save()
          } catch {
            AppLogger.logError(
              .from(
                error: error,
                operation: "Delete provider",
                component: "ProviderListView"
              ))
          }
        }
        providersToDelete = []
      }
    } message: {
      if providersToDelete.count == 1 {
        Text("This provider will be permanently deleted.")
      } else {
        Text("\(providersToDelete.count) providers will be permanently deleted.")
      }
    }
  }

  func deleteProviders(at offsets: IndexSet) {
    providersToDelete = offsets.map { providers[$0] }
    isDeleteProviderConfirmPresented = true
  }
}

struct ProviderRow: View {
  let provider: Provider

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(provider.displayName)
          .font(.body)
          .foregroundColor(provider.enabled ? .primary : .secondary)

        Text("\(provider.models.count) model\(provider.models.count == 1 ? "" : "s")")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
  }
}

#Preview {
  ModelContainerPreview(ModelContainer.preview) {
    NavigationStack {
      ProviderListView()
    }
  }
}
