import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

struct FileRowView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    let item: FileItem
    let panelID: UUID
    let nameColumnWidth: CGFloat
    let dateColumnWidth: CGFloat
    let onOpen: () -> Void
    let onActivate: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // System file icon (macOS native — same as Finder)
            Image(nsImage: systemIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
                .frame(width: 40)           // fixed icon column

            // Name
            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: nameColumnWidth, alignment: .leading)

            // Modification date
            Text(item.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: dateColumnWidth, alignment: .leading)

            // Size
            Text(formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .gesture(
            TapGesture(count: 2).onEnded { onOpen() }
                .exclusively(before: TapGesture(count: 1).onEnded { onActivate() })
        )
        .onDrag {
            appViewModel.startDrag(item: item, fromPanelID: panelID)
            return NSItemProvider(object: item.url as NSURL)
        }
    }

    // MARK: - Helpers

    /// Returns the native macOS system icon for this file type (same icons Finder uses).
    private var systemIcon: NSImage {
        if item.isDirectory {
            return NSWorkspace.shared.icon(for: UTType.folder)
        }
        if !item.fileExtension.isEmpty,
           let uti = UTType(filenameExtension: item.fileExtension) {
            return NSWorkspace.shared.icon(for: uti)
        }
        // Fallback: icon from the actual file path
        return NSWorkspace.shared.icon(forFile: item.url.path)
    }

    private var formattedSize: String {
        guard let size = item.fileSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
