import SwiftUI
import Combine

struct SidebarView: View {
    @ObservedObject var viewModel: FileViewModel

    var body: some View {
        List(selection: $viewModel.selectedItem) {
            ForEach(viewModel.items) { item in
                Label(item.name, systemImage: item.isDirectory ? "folder" : "doc")
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.openFolder()
                } label: {
                    Label("폴더 열기", systemImage: "folder.badge.plus")
                }
            }
        }
    }
}
