import Foundation
import Combine
import AppKit

enum RenameMode {
    case batchNumbering
    case individualRename
}

enum NumberPosition {
    case prefix   // 001_이름.jpg
    case suffix   // 이름_001.jpg
}

enum NumberPadding: String, CaseIterable {
    case none   = "1"
    case double = "01"
    case triple = "001"

    func format(_ n: Int) -> String {
        switch self {
        case .none:   return "\(n)"
        case .double: return String(format: "%02d", n)
        case .triple: return String(format: "%03d", n)
        }
    }
}

struct RenameItem: Identifiable {
    let id = UUID()
    let url: URL
    var customName: String
    var isSelected: Bool = true

    var originalName: String { url.deletingPathExtension().lastPathComponent }
    var fileExtension: String { url.pathExtension }
}

class FileRenamerViewModel: ObservableObject {
    @Published var folderURL: URL?
    @Published var items: [RenameItem] = []
    @Published var mode: RenameMode = .batchNumbering
    @Published var baseName: String = ""
    @Published var startNumber: Int = 1
    @Published var numberPosition: NumberPosition = .suffix
    @Published var numberPadding: NumberPadding = .triple
    @Published var completionMessage: String?
    @Published var showDuplicateAlert = false
    @Published var focusedItemID: UUID? = nil

    // 모드 B에서 중복 최종파일명(이름+확장자)을 가진 항목의 ID 집합
    // 현재 편집 중인 항목(focusedItemID)은 포커스를 벗어나기 전까지 비교에서 제외
    var duplicateIDs: Set<UUID> {
        guard mode == .individualRename else { return [] }
        var nameMap: [String: [UUID]] = [:]
        for item in items {
            if item.id == focusedItemID { continue }
            let name = item.customName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let fullName = item.fileExtension.isEmpty ? name : "\(name).\(item.fileExtension)"
            nameMap[fullName, default: []].append(item.id)
        }
        var result = Set<UUID>()
        for (_, ids) in nameMap where ids.count > 1 {
            ids.forEach { result.insert($0) }
        }
        return result
    }

    // 선택 관련
    var selectedCount: Int { items.filter { $0.isSelected }.count }
    var allSelected: Bool { !items.isEmpty && items.allSatisfy { $0.isSelected } }
    var someSelected: Bool { items.contains { $0.isSelected } }

    func toggleSelectAll() {
        let newValue = !allSelected
        for i in items.indices { items[i].isSelected = newValue }
    }

    // 중복된 파일명 목록 (알림용)
    var duplicateNameList: [String] {
        var nameMap: [String: Int] = [:]
        for item in items {
            let name = item.customName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let fullName = item.fileExtension.isEmpty ? name : "\(name).\(item.fileExtension)"
            nameMap[fullName, default: 0] += 1
        }
        return nameMap.filter { $0.value > 1 }.map { $0.key }.sorted()
    }

    func loadFolder(_ url: URL) {
        folderURL = url
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let files = contents
            .filter { !$0.hasDirectoryPath }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        items = files.map { RenameItem(url: $0, customName: $0.deletingPathExtension().lastPathComponent) }
        completionMessage = nil
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"
        if panel.runModal() == .OK, let url = panel.url {
            loadFolder(url)
        }
    }

    func previewName(for item: RenameItem) -> String {
        let ext = item.fileExtension.isEmpty ? "" : ".\(item.fileExtension)"
        switch mode {
        case .batchNumbering:
            guard !baseName.isEmpty, item.isSelected else { return item.url.lastPathComponent }
            let selectedItems = items.filter { $0.isSelected }
            let selectedIndex = selectedItems.firstIndex(where: { $0.id == item.id }) ?? 0
            let number = numberPadding.format(startNumber + selectedIndex)
            switch numberPosition {
            case .suffix: return "\(baseName)_\(number)\(ext)"
            case .prefix: return "\(number)_\(baseName)\(ext)"
            }
        case .individualRename:
            let name = item.customName.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? item.url.lastPathComponent : "\(name)\(ext)"
        }
    }

    func saveInPlace() {
        if mode == .individualRename && !duplicateIDs.isEmpty {
            showDuplicateAlert = true
            return
        }
        let fm = FileManager.default
        for item in items {
            let newName = previewName(for: item)
            guard newName != item.url.lastPathComponent else { continue }
            let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
            try? fm.moveItem(at: item.url, to: newURL)
        }
        if let folder = folderURL {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadFolder(folder)
                self.completionMessage = "이름 변경 완료!"
            }
        }
    }

    func saveAsCopy() {
        if mode == .individualRename && !duplicateIDs.isEmpty {
            showDuplicateAlert = true
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "저장 위치 선택"
        guard panel.runModal() == .OK, let destFolder = panel.url else { return }
        let fm = FileManager.default
        for item in items {
            let newName = previewName(for: item)
            var destURL = destFolder.appendingPathComponent(newName)
            if fm.fileExists(atPath: destURL.path) {
                let base = destURL.deletingPathExtension().lastPathComponent
                let ext = destURL.pathExtension
                var counter = 2
                repeat {
                    destURL = destFolder.appendingPathComponent(
                        ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
                    )
                    counter += 1
                } while fm.fileExists(atPath: destURL.path)
            }
            try? fm.copyItem(at: item.url, to: destURL)
        }
        completionMessage = "복사 완료 → \(destFolder.lastPathComponent)"
    }

    func handleDrop(urls: [URL]) {
        guard let url = urls.first, url.hasDirectoryPath else { return }
        loadFolder(url)
    }

    func reset() {
        folderURL = nil
        items = []
        baseName = ""
        startNumber = 1
        numberPosition = .suffix
        numberPadding = .triple
        completionMessage = nil
    }
}
