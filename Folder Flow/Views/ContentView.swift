import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = FileViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            PanelView(viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
