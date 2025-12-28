import SwiftUI
import UIKit

struct HomePage: View {
    var body: some View {
        //    //let _ = Self.printChagesWhenDebug()
        if UIDevice.current.userInterfaceIdiom == .pad {
            HomePage_iPad()
        } else {
            HomePage_iOS()
        }
    }
}

#Preview {
    LovelyPreview {
        HomePage()
    }
}
