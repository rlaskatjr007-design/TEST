import Foundation
import Combine
import AppKit

struct ArchiveItem: Identifiable {
    let id = UUID()
    let url: URL
    var isSelected: Bool = true

    var name: String { url.lastPathComponent }
    var fileExtension: String { url.pathExtension.lowercased() }
    var fileSize: Int64? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map { Int64($0) }
    }
    var modificationDate: Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}

class ArchiveCleanerViewModel: ObservableObject {
    @Published var selectedFolder: URL?
    @Published var items: [ArchiveItem] = []
    @Published var isScanning = false
    @Published var completionMessage: String?

    private let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz"]

    // MARK: - Folder Selection

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            scan()
        }
    }

    func handleDrop(urls: [URL]) {
        let fm = FileManager.default
        for url in urls {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                selectedFolder = url
                scan()
                return
            }
        }
    }

    func clearFolder() {
        selectedFolder = nil
        items = []
        completionMessage = nil
    }

    // MARK: - Scan

    func scan() {
        guard let folder = selectedFolder else { return }
        completionMessage = nil
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let contents = (try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: .skipsHiddenFiles
            )) ?? []

            let archiveFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return !isDir && self.archiveExtensions.contains(ext)
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }

            let newItems = archiveFiles.map { ArchiveItem(url: $0) }

            DispatchQueue.main.async {
                self.items = newItems
                self.isScanning = false
            }
        }
    }

    // MARK: - Selection

    var allSelected: Bool {
        !items.isEmpty && items.allSatisfy { $0.isSelected }
    }

    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    var selectedTotalSize: Int64 {
        items.filter { $0.isSelected }.compactMap { $0.fileSize }.reduce(0, +)
    }

    func toggleSelectAll() {
        let newValue = !allSelected
        for i in items.indices {
            items[i].isSelected = newValue
        }
    }

    // MARK: - Delete

    func deleteSelected() {
        let toDelete = items.filter { $0.isSelected }.map { $0.url }
        guard !toDelete.isEmpty else { return }

        NSWorkspace.shared.recycle(toDelete) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.completionMessage = "\(toDelete.count)개 파일을 휴지통으로 이동했습니다."
                self.scan()
            }
        }
    }
}
