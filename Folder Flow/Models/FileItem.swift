import Foundation

struct FileItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let isDirectory: Bool

    init(id: UUID = UUID(), name: String, url: URL, isDirectory: Bool) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
    }
}
