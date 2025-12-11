import ConfettiSwiftUI
import os
import StoreKit
import SwiftData
import SwiftUI

struct SettingView: View {
  @EnvironmentObject var pref: Pref
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) var modelContext
  @EnvironmentObject var storeVM: StoreVM
  @Environment(\.openURL) var openURL
  @State var safariAddr: String? = nil
  @State var showViewLogs = false

  var body: some View {
    NavigationView {
      List {
        appearanceSection
                
        appSection
        
        newChatPreferenceSection
        
        supportSection
        
        aboutSection
        
        dangerZoneLink
        
        #if DEBUG
        debugZoneLink
        #endif
        
        purchaseSection
        
        Color.clear.frame(height: 100)
          .listRowBackground(Color.clear)
      }
      .animation(.default, value: colorScheme)
      .confettiCannon(trigger: $storeVM.coffeeCount, num: 100, radius: 400)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  LovelyPreview {
    SettingView()
  }
}
