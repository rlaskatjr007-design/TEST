import SwiftUI
import UniformTypeIdentifiers

struct ImageOrganizerView: View {
    @StateObject private var vm = ImageOrganizerViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(width: 300)
            Divider()
            rightPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let u = item as? URL {
                        url = u
                    }
                    if let url = url {
                        DispatchQueue.main.async { self.vm.handleDrop(urls: [url]) }
                    }
                }
            }
            return true
        }
        .overlay(
            isDropTargeted
                ? RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .allowsHitTesting(false)
                : nil
        )
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("이미지 날짜별 정리")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    folderSection
                    if vm.selectedFolder != nil { optionSection }
                    if !vm.previewGroups.isEmpty { organizeSection }
                    if let msg = vm.completionMessage { completionBanner(msg) }
                }
                .padding(14)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Folder Section

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("폴더 선택")
                .font(.subheadline.weight(.medium))

            if let folder = vm.selectedFolder {
                // Selected state
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.lastPathComponent)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(folder.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button { vm.clearFolder() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1))
                )

                Button("다른 폴더 선택") { vm.selectFolder() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            } else {
                // Drop zone
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 30))
                        .foregroundColor(isDropTargeted ? .accentColor : .secondary)
                    Text("폴더를 여기에 드래그")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("또는")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    Button("폴더 선택") { vm.selectFolder() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color(NSColor.separatorColor),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isDropTargeted ? Color.accentColor.opacity(0.04) : Color.clear)
                        )
                )
            }
        }
    }

    // MARK: - Option Section

    private var optionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("정리 방식")
                .font(.subheadline.weight(.medium))

            ForEach(OrganizeOption.allCases, id: \.self) { opt in
                Button {
                    vm.option = opt
                    vm.buildPreview()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: vm.option == opt ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(vm.option == opt ? .accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(opt.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            Text(opt.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(vm.option == opt
                                  ? Color.accentColor.opacity(0.08)
                                  : Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(
                                        vm.option == opt ? Color.accentColor.opacity(0.3) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            if let folder = vm.selectedFolder {
                let exPath = vm.option == .a
                    ? "\(folder.lastPathComponent)/이미지/2026-03-25/"
                    : "\(folder.lastPathComponent)/2026-03-25/"
                Text(exPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
            }
        }
    }

    // MARK: - Organize Section

    private var organizeSection: some View {
        VStack(spacing: 8) {
            let total = vm.previewGroups.reduce(0) { $0 + $1.files.count }
            Text("이미지 \(total)개 · 날짜 그룹 \(vm.previewGroups.count)개")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                vm.organize()
            } label: {
                HStack(spacing: 6) {
                    if vm.isOrganizing {
                        ProgressView().controlSize(.small)
                    }
                    Text(vm.isOrganizing ? "정리 중..." : "정리 시작")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(vm.isOrganizing)
        }
    }

    private func completionBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Right Panel (Preview)

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("미리보기")
                    .font(.headline)
                Spacer()
                if !vm.previewGroups.isEmpty {
                    Button { vm.buildPreview() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            if vm.selectedFolder == nil {
                emptyState(
                    icon: "folder.badge.questionmark",
                    text: "폴더를 선택하면\n날짜별 미리보기가 표시됩니다"
                )
            } else if vm.previewGroups.isEmpty {
                emptyState(
                    icon: "photo.stack",
                    text: "이미지 파일이 없습니다\n(.jpg .jpeg .png .gif .heic .webp)"
                )
            } else {
                previewList
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(vm.previewGroups) { group in
                    PreviewGroupRow(group: group, option: vm.option, baseFolder: vm.selectedFolder!)
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Preview Group Row

private struct PreviewGroupRow: View {
    let group: PreviewGroup
    let option: OrganizeOption
    let baseFolder: URL
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    Image(systemName: "folder.fill")
                        .foregroundColor(.yellow)
                        .font(.subheadline)

                    Text(group.dateString)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)

                    Text(group.targetFolderExists ? "기존 폴더에 추가" : "새 폴더")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                group.targetFolderExists
                                    ? Color.orange.opacity(0.15)
                                    : Color.green.opacity(0.15)
                            )
                        )
                        .foregroundColor(group.targetFolderExists ? .orange : .green)

                    Spacer()

                    Text("\(group.files.count)개")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.windowBackgroundColor))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(group.files, id: \.self) { file in
                        HStack(spacing: 6) {
                            Color.clear.frame(width: 16)
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            Text(file.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .padding(.leading, 8)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}
