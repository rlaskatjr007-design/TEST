import SwiftUI
import Combine

struct PanelView: View {
    @ObservedObject var viewModel: FileViewModel

    var body: some View {
        Group {
            if let selected = viewModel.selectedItem {
                VStack(alignment: .leading, spacing: 12) {
                    Label(selected.name, systemImage: selected.isDirectory ? "folder" : "doc")
                        .font(.title2)
                        .padding()
                    Text(selected.url.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("항목을 선택하세요")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("사이드바에서 파일 또는 폴더를 선택하세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

