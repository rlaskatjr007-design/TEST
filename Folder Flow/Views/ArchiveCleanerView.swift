import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ArchiveCleanerView: View {
    @StateObject private var vm = ArchiveCleanerViewModel()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HSplitView {
            leftPanel
                .frame(minWidth: 420)
            rightPanel
                .frame(minWidth: 200, maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            folderHeader
            Divider()

            if vm.selectedFolder == nil {
                dropZone
            } else if vm.isScanning {
                scanningView
            } else if vm.items.isEmpty {
                emptyResult
            } else {
                fileList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Folder Header

    private var folderHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            if let folder = vm.selectedFolder {
                Text(folder.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("폴더를 선택하세요")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if vm.selectedFolder != nil {
                Button {
                    vm.scan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("다시 스캔")
            }

            Button {
                vm.selectFolder()
            } label: {
                Text("폴더 선택")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            if vm.selectedFolder != nil {
                Button {
                    vm.clearFolder()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(24)

            VStack(spacing: 8) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("폴더를 드래그하거나 위에서 선택하세요")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            _ = providers.first?.loadObject(ofClass: NSURL.self) { item, _ in
                if let url = item as? URL {
                    DispatchQueue.main.async { vm.handleDrop(urls: [url]) }
                }
            }
            return true
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("스캔 중...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Result

    private var emptyResult: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("압축 파일이 없습니다")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File List

    private var fileList: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { vm.allSelected },
                    set: { _ in vm.toggleSelectAll() }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()

                Text("파일명")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("크기")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)

                Text("수정일")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.items.indices, id: \.self) { i in
                        archiveRow(index: i)
                        if i < vm.items.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }

            Divider()

            // Bottom action bar
            HStack {
                Text("전체 \(vm.items.count)개 · \(vm.selectedCount)개 선택됨")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    vm.deleteSelected()
                } label: {
                    Label("선택 항목 삭제", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(vm.selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func archiveRow(index: Int) -> some View {
        let item = vm.items[index]
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { vm.items[index].isSelected },
                set: { vm.items[index].isSelected = $0 }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            // Extension badge
            Text(item.fileExtension.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(badgeColor(for: item.fileExtension))
                .cornerRadius(3)
                .frame(width: 32)

            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(formattedSize(item.fileSize))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            Text(item.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(item.isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.items[index].isSelected.toggle()
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("요약")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                summaryRow(
                    icon: "archivebox",
                    label: "발견된 파일",
                    value: "\(vm.items.count)개"
                )
                summaryRow(
                    icon: "checkmark.square",
                    label: "선택된 파일",
                    value: "\(vm.selectedCount)개"
                )
                summaryRow(
                    icon: "internaldrive",
                    label: "삭제 예정 용량",
                    value: formattedSize(vm.selectedTotalSize)
                )
            }
            .padding(16)

            Divider()

            // Extension breakdown
            if !vm.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("확장자별")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    ForEach(extensionSummary(), id: \.ext) { entry in
                        HStack {
                            Text(entry.ext.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(badgeColor(for: entry.ext))
                                .cornerRadius(3)
                            Text("\(entry.count)개")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formattedSize(entry.size))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
            }

            Spacer()

            if let msg = vm.completionMessage {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
            }
        }
    }

    // MARK: - Helpers

    private func formattedSize(_ size: Int64?) -> String {
        guard let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func formattedSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func badgeColor(for ext: String) -> Color {
        switch ext {
        case "zip": return .blue
        case "rar": return .purple
        case "7z":  return .orange
        case "tar": return .brown
        case "gz":  return .teal
        default:    return .gray
        }
    }

    private struct ExtEntry { let ext: String; let count: Int; let size: Int64 }

    private func extensionSummary() -> [ExtEntry] {
        var dict: [String: (Int, Int64)] = [:]
        for item in vm.items {
            let ext = item.fileExtension
            let current = dict[ext] ?? (0, 0)
            dict[ext] = (current.0 + 1, current.1 + (item.fileSize ?? 0))
        }
        return dict.map { ExtEntry(ext: $0.key, count: $0.value.0, size: $0.value.1) }
            .sorted { $0.count > $1.count }
    }
}

#Preview {
    ArchiveCleanerView()
}
