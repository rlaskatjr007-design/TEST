import SwiftUI

@main
struct FolderFlowApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .preferredColorScheme(.light)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 750)
    }
}
