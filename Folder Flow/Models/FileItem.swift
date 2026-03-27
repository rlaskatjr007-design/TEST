import Foundation

struct FileItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let isDirectory: Bool
    let fileExtension: String
    let modificationDate: Date?
    let fileSize: Int64?

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        isDirectory: Bool,
        fileExtension: String = "",
        modificationDate: Date? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.fileExtension = fileExtension
        self.modificationDate = modificationDate
        self.fileSize = fileSize
    }

    // MARK: - Sort helpers (non-optional, for Table SortDescriptor)

    var sortDate: Date  { modificationDate ?? .distantPast }
    var sortSize: Int64 { fileSize ?? 0 }

    // MARK: - Extension grouping

    var fileGroupName: String {
        if isDirectory { return "폴더" }
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "raw", "svg":
            return "이미지"
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm":
            return "동영상"
        case "mp3", "m4a", "wav", "aac", "flac", "ogg", "opus":
            return "오디오"
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
             "pages", "numbers", "key", "hwp":
            return "문서"
        case "swift", "js", "ts", "jsx", "tsx", "py", "rb", "go",
             "java", "c", "cpp", "h", "html", "css", "json",
             "xml", "yml", "yaml", "sh", "bash", "php", "rs":
            return "코드"
        case "zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "pkg", "iso":
            return "압축·설치"
        case "txt", "md", "rtf", "csv", "log":
            return "텍스트"
        case "app":
            return "앱"
        case "ttf", "otf", "woff", "woff2":
            return "폰트"
        default:
            return fileExtension.isEmpty ? "기타" : fileExtension.uppercased()
        }
    }

    /// Display-friendly size string
    var formattedSize: String {
        guard let size = fileSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
