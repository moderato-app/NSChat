import SwiftUI

struct ProviderConfigurationForm: View {
  @Bindable var provider: Provider
  let mode: ProviderViewMode
  @EnvironmentObject var em: EM

  @State private var isPasswordVisible = false
  @FocusState private var isApiKeyFocused: Bool

  var body: some View {
    Section {
      Picker("Provider", selection: $provider.type) {
        ForEach(ProviderType.allCases, id: \.self) { type in
          Text(type.displayName)
            .tag(type)
            .selectionDisabled(!type.isSupportedByNSChat)
        }
      }
    } header: {
      Text("Type")
    }

    Section("Name") {
      TextField(provider.type.displayName, text: $provider.alias)
        .textContentType(.name)
        .submitLabel(.done)
    }

    Section {
      Group {
        if isPasswordVisible {
          TextField("", text: $provider.apiKey)
            .focused($isApiKeyFocused)
        } else {
          SecureField("", text: $provider.apiKey)
            .focused($isApiKeyFocused)
        }
      }
      .textContentType(.password)
      .submitLabel(.done)
      .onAppear { isApiKeyFocused = (mode == .Add) }
      .onChange(of: isApiKeyFocused) { _, b in
        guard mode == .Add, !b, provider.apiKey.isMeaningful else { return }
        em.shouldFetchModels.send(provider.persistentModelID)
      }
    } header: {
      HStack {
        Text("API Key")
        Spacer()
        Button(action: { isPasswordVisible.toggle() }) {
          Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
            .foregroundColor(.secondary)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: isPasswordVisible)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
      }
    }

    Section("Endpoint") {
      TextField("Optional", text: $provider.endpoint)
        .textContentType(.URL)
        .autocapitalization(.none)
        .submitLabel(.done)
    }

    if mode == .Edit {
      Section {
        Toggle("Enabled", isOn: $provider.enabled)
      }
    }
  }
}
