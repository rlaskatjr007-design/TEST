import Foundation
import Combine
import AppKit

enum OrganizeOption: CaseIterable {
    case a, b

    var title: String {
        switch self {
        case .a: return "옵션 A"
        case .b: return "옵션 B"
        }
    }

    var subtitle: String {
        switch self {
        case .a: return "이미지/ 폴더 안에 날짜별 정리"
        case .b: return "날짜 폴더만 바로 생성"
        }
    }
}

struct PreviewGroup: Identifiable {
    let id = UUID()
    let dateString: String
    let files: [URL]
    let targetFolderExists: Bool
}

class ImageOrganizerViewModel: ObservableObject {
    @Published var selectedFolder: URL?
    @Published var option: OrganizeOption = .a
    @Published var previewGroups: [PreviewGroup] = []
    @Published var isOrganizing = false
    @Published var completionMessage: String?
    @Published private(set) var lastMoves: [(from: URL, to: URL)] = []

    var canUndo: Bool { !lastMoves.isEmpty }

    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "webp"]

    // MARK: - Folder Selection

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"
        if panel.runModal() == .OK, let url = panel.url {
            if url != selectedFolder { lastMoves = [] }
            selectedFolder = url
            buildPreview()
        }
    }

    func handleDrop(urls: [URL]) {
        let fm = FileManager.default
        for url in urls {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if url != selectedFolder { lastMoves = [] }
                selectedFolder = url
                buildPreview()
                return
            }
        }
    }

    func clearFolder() {
        selectedFolder = nil
        previewGroups = []
        completionMessage = nil
        lastMoves = []
    }

    // MARK: - Preview

    func buildPreview() {
        guard let folder = selectedFolder else {
            previewGroups = []
            return
        }
        completionMessage = nil

        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        )) ?? []

        let imageFiles = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return !isDir && imageExtensions.contains(ext)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var groups: [String: [URL]] = [:]
        for file in imageFiles {
            let date = bestDate(for: file)
            let key = formatter.string(from: date)
            groups[key, default: []].append(file)
        }

        let sortedKeys = groups.keys.sorted(by: >)

        previewGroups = sortedKeys.map { key in
            let targetExists: Bool
            switch option {
            case .a:
                let dateFolder = folder.appendingPathComponent("이미지").appendingPathComponent(key)
                targetExists = fm.fileExists(atPath: dateFolder.path)
            case .b:
                let dateFolder = folder.appendingPathComponent(key)
                targetExists = fm.fileExists(atPath: dateFolder.path)
            }
            let sortedFiles = (groups[key] ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
            return PreviewGroup(dateString: key, files: sortedFiles, targetFolderExists: targetExists)
        }
    }

    // MARK: - Date Resolution

    /// 수정일(contentModificationDate) 기준, 없으면 현재 날짜
    private func bestDate(for url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? Date()
    }

    // MARK: - Organize

    func organize() {
        guard let folder = selectedFolder, !previewGroups.isEmpty else { return }
        isOrganizing = true
        completionMessage = nil
        lastMoves = []

        let fm = FileManager.default
        let groupsToProcess = previewGroups

        DispatchQueue.global(qos: .userInitiated).async {
            var movedCount = 0
            var moves: [(from: URL, to: URL)] = []

            for group in groupsToProcess {
                let dateFolder: URL
                switch self.option {
                case .a:
                    let imgFolder = folder.appendingPathComponent("이미지")
                    try? fm.createDirectory(at: imgFolder, withIntermediateDirectories: true)
                    dateFolder = imgFolder.appendingPathComponent(group.dateString)
                case .b:
                    dateFolder = folder.appendingPathComponent(group.dateString)
                }
                try? fm.createDirectory(at: dateFolder, withIntermediateDirectories: true)

                for file in group.files {
                    var dest = dateFolder.appendingPathComponent(file.lastPathComponent)
                    if fm.fileExists(atPath: dest.path) {
                        let name = file.deletingPathExtension().lastPathComponent
                        let ext  = file.pathExtension
                        var counter = 2
                        repeat {
                            let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
                            dest = dateFolder.appendingPathComponent(newName)
                            counter += 1
                        } while fm.fileExists(atPath: dest.path)
                    }
                    if (try? fm.moveItem(at: file, to: dest)) != nil {
                        movedCount += 1
                        moves.append((from: dest, to: file))
                    }
                }
            }

            DispatchQueue.main.async {
                self.isOrganizing = false
                self.lastMoves = moves
                self.completionMessage = "\(movedCount)개 파일을 날짜별로 정리 완료했습니다."
                self.buildPreview()
            }
        }
    }

    func undo() {
        let moves = lastMoves
        let rootFolder = selectedFolder
        lastMoves = []
        isOrganizing = true
        let fm = FileManager.default
        DispatchQueue.global(qos: .userInitiated).async {
            var restoredCount = 0
            var dateFolders = Set<URL>()

            for move in moves {
                if (try? fm.moveItem(at: move.from, to: move.to)) != nil {
                    restoredCount += 1
                    dateFolders.insert(move.from.deletingLastPathComponent())
                }
            }

            // 비어있는 날짜 폴더 삭제
            for folder in dateFolders {
                let contents = (try? fm.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
                )) ?? []
                guard contents.isEmpty else { continue }
                try? fm.removeItem(at: folder)

                // 날짜 폴더의 부모(예: 이미지/)도 비어있으면 삭제 (단, 루트 폴더 제외)
                let parent = folder.deletingLastPathComponent()
                guard parent != rootFolder else { continue }
                let parentContents = (try? fm.contentsOfDirectory(
                    at: parent, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
                )) ?? []
                if parentContents.isEmpty {
                    try? fm.removeItem(at: parent)
                }
            }

            DispatchQueue.main.async {
                self.isOrganizing = false
                self.completionMessage = "\(restoredCount)개 파일을 원래 위치로 되돌렸습니다."
                self.buildPreview()
            }
        }
    }
}
