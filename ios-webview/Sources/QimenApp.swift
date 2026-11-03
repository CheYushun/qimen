import SwiftUI
import UIKit

@main
struct QimenApp: App {
    var body: some Scene {
        WindowGroup {
            WebShell()
                .ignoresSafeArea()
                .preferredColorScheme(.light)
        }
    }
}
