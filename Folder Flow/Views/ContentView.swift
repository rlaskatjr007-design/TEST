import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 220)
            Divider()
            PanelGridView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
