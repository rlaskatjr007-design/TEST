import SwiftUI
import Combine

class FileViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var selectedItem: FileItem?

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "열 폴더를 선택하세요"
        panel.prompt = "열기"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadContents(of: url)
    }

    private func loadContents(of url: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return }

        items = contents.map { fileURL in
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: isDir)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        selectedItem = nil
    }
}
