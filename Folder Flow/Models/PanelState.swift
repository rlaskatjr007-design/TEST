import Foundation
import Combine

class PanelState: ObservableObject, Identifiable {
    let id = UUID()
    @Published var currentURL: URL?
    @Published var items: [FileItem] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false

    private var history: [URL] = []
    private var historyIndex: Int = -1

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .contentModificationDateKey,
        .fileSizeKey
    ]

    // MARK: - Navigation

    /// 히스토리에 추가하며 이동 (폴더 더블클릭, 뒤로/앞으로)
    func navigate(to url: URL) {
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        history.append(url)
        historyIndex = history.count - 1
        updateNavState()
        currentURL = url
        selectedIDs = []
        loadContents()
    }

    /// 히스토리를 초기화하고 새 위치로 이동 (사이드바 클릭)
    func resetTo(_ url: URL) {
        history = [url]
        historyIndex = 0
        updateNavState()
        currentURL = url
        loadContents()
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        currentURL = history[historyIndex]
        updateNavState()
        loadContents()
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        currentURL = history[historyIndex]
        updateNavState()
        loadContents()
    }

    func refresh() {
        loadContents()
    }

    private func updateNavState() {
        canGoBack = historyIndex > 0
        canGoForward = historyIndex < history.count - 1
    }

    // MARK: - File Loading

    private func loadContents() {
        guard let url = currentURL else {
            items = []
            return
        }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Self.resourceKeys,
            options: .skipsHiddenFiles
        ) else { return }

        items = contents.compactMap { fileURL -> FileItem? in
            let rv = try? fileURL.resourceValues(forKeys: Set(Self.resourceKeys))
            let isDir = rv?.isDirectory ?? false
            let modDate = rv?.contentModificationDate
            let size = rv?.fileSize.map { Int64($0) }
            let ext = isDir ? "" : fileURL.pathExtension.lowercased()

            return FileItem(
                name: fileURL.lastPathComponent,
                url: fileURL,
                isDirectory: isDir,
                fileExtension: ext,
                modificationDate: modDate,
                fileSize: isDir ? nil : size
            )
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}
