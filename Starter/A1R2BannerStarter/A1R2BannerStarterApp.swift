// A1R2Banner — Starter example.
// A minimal SwiftUI app (iOS + tvOS) that demonstrates the SDK end to end.

import SwiftUI

@main
struct A1R2BannerStarterApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("--layout-review") {
                LayoutGallery()
            } else {
                ContentView()
            }
        }
    }
}
