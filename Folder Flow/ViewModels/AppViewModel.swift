import Foundation
import Combine
import AppKit

class AppViewModel: ObservableObject {
    @Published var panels: [PanelState] = []
    @Published var panelCount: Int = 2
    @Published var activePanelID: UUID?
    @Published var volumes: [URL] = []

    // Drag state — set from onDrag, read in onDrop
    private(set) var draggingFromPanelID: UUID?
    private(set) var pendingDragURLs: [URL] = []

    var activePanel: PanelState? {
        panels.first { $0.id == activePanelID }
    }

    init() {
        adjustPanels(to: 2)
        loadVolumes()
    }

    // MARK: - Panel Management

    func setPanelCount(_ count: Int) {
        panelCount = count
        adjustPanels(to: count)
    }

    private func adjustPanels(to count: Int) {
        if panels.count < count {
            while panels.count < count {
                panels.append(PanelState())
            }
        } else if panels.count > count {
            panels = Array(panels.prefix(count))
        }
        if let id = activePanelID, !panels.contains(where: { $0.id == id }) {
            activePanelID = panels.first?.id
        }
    }

    func activatePanel(_ panel: PanelState) {
        // 이전 패널의 selection 초기화
        if let prev = activePanel, prev.id != panel.id {
            prev.selectedIDs = []
        }
        activePanelID = panel.id
    }

    func openInActivePanel(_ url: URL) {
        let target = activePanel ?? panels.first
        target?.resetTo(url)
        if let target = target {
            activePanelID = target.id
        }
    }

    // MARK: - Sidebar Volumes

    func loadVolumes() {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        let all = (try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: .skipsHiddenFiles
        )) ?? []
        volumes = all.filter { url in
            let isSymlink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
            return !isSymlink
        }
    }

    // MARK: - Drag & Drop

    /// selection이 2개 이상이고 드래그한 item이 선택에 포함되면 전체 선택 이동
    func startDrag(item: FileItem, fromPanelID: UUID, selection: Set<UUID>, allItems: [FileItem]) {
        draggingFromPanelID = fromPanelID
        if selection.contains(item.id) && selection.count > 1 {
            pendingDragURLs = allItems.filter { selection.contains($0.id) }.map(\.url)
        } else {
            pendingDragURLs = [item.url]
        }
    }

    func completeDrop(sourceURL: URL, to destinationDir: URL, destinationPanel: PanelState) {
        // 앱 내부 멀티 드래그: sourceURL이 pendingDragURLs에 있으면 전체 이동
        let urlsToMove: [URL]
        if pendingDragURLs.contains(sourceURL) {
            urlsToMove = pendingDragURLs
        } else {
            // 외부 드래그(Finder 등): 단일 파일만 처리
            urlsToMove = [sourceURL]
        }
        pendingDragURLs = []

        let dst = destinationDir.standardizedFileURL
        let fm = FileManager.default
        for src in urlsToMove {
            guard src.deletingLastPathComponent().standardizedFileURL != dst else { continue }
            var dest = destinationDir.appendingPathComponent(src.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                let name = src.deletingPathExtension().lastPathComponent
                let ext  = src.pathExtension
                var counter = 2
                repeat {
                    dest = destinationDir.appendingPathComponent(
                        ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
                    )
                    counter += 1
                } while fm.fileExists(atPath: dest.path)
            }
            try? fm.moveItem(at: src, to: dest)
        }

        destinationPanel.refresh()
        if let fromID = draggingFromPanelID,
           let sourcePanel = panels.first(where: { $0.id == fromID }) {
            sourcePanel.refresh()
        }
        draggingFromPanelID = nil
    }

    // MARK: - File Operations

    func copyFiles(_ urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
    }

    func hasPasteboardFiles() -> Bool {
        NSPasteboard.general.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: NSNumber(value: true)]
        )
    }

    func pasteFiles(to dir: URL, panel: PanelState) {
        guard let urls = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: NSNumber(value: true)]
        ) as? [URL] else { return }
        for srcURL in urls {
            let dest = uniqueDestURL(for: srcURL, in: dir)
            try? FileManager.default.copyItem(at: srcURL, to: dest)
        }
        panel.refresh()
    }

    func duplicateFile(_ url: URL, panel: PanelState) {
        let dir = url.deletingLastPathComponent()
        let dest = uniqueDestURL(for: url, in: dir, suffix: " 복사본")
        try? FileManager.default.copyItem(at: url, to: dest)
        panel.refresh()
    }

    func moveToTrash(_ url: URL, panel: PanelState) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        panel.refresh()
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func showNewFolderDialog(in dir: URL, panel: PanelState) {
        let alert = NSAlert()
        alert.messageText = "새 폴더"
        alert.informativeText = "폴더 이름을 입력하세요"
        alert.addButton(withTitle: "만들기")
        alert.addButton(withTitle: "취소")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        tf.stringValue = "새 폴더"
        tf.selectText(nil)
        alert.accessoryView = tf
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        try? FileManager.default.createDirectory(
            at: dir.appendingPathComponent(name),
            withIntermediateDirectories: false
        )
        panel.refresh()
    }

    func showRenameDialog(for url: URL, panel: PanelState) {
        let alert = NSAlert()
        alert.messageText = "이름 변경"
        alert.addButton(withTitle: "변경")
        alert.addButton(withTitle: "취소")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        tf.stringValue = url.lastPathComponent
        tf.selectText(nil)
        alert.accessoryView = tf
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = tf.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != url.lastPathComponent else { return }
        let dest = url.deletingLastPathComponent().appendingPathComponent(newName)
        try? FileManager.default.moveItem(at: url, to: dest)
        panel.refresh()
    }

    // MARK: - Private helpers

    private func uniqueDestURL(for srcURL: URL, in dir: URL, suffix: String = "") -> URL {
        let name = srcURL.deletingPathExtension().lastPathComponent
        let ext  = srcURL.pathExtension
        let base = suffix.isEmpty
            ? srcURL.lastPathComponent
            : (ext.isEmpty ? "\(name)\(suffix)" : "\(name)\(suffix).\(ext)")
        var candidate = dir.appendingPathComponent(base)
        var counter   = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent(
                ext.isEmpty ? "\(name)\(suffix) \(counter)" : "\(name)\(suffix) \(counter).\(ext)"
            )
            counter += 1
        }
        return candidate
    }
}
