import SwiftUI

struct `EmptyProviderCard`: View {
  let onAddProvider: () -> Void
  
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "cube.box")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text("No AI Providers")
        .font(.headline)

      Text("Add a provider to get started")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button {
        onAddProvider()
      } label: {
        HStack {
          Image(systemName: "plus.circle.fill")
            .backgroundStyle(.foreground)
          Text("Add Provider")
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .padding(.horizontal, 20)
  }
}

