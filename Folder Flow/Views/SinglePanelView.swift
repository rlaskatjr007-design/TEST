import SwiftUI
import Combine
import UniformTypeIdentifiers
import AppKit

struct SinglePanelView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var panel: PanelState
    @State private var isDropTargeted = false
    @State private var groupByExtension = false
    @State private var selection: Set<UUID> = []
    @State private var hoverBack = false
    @State private var hoverForward = false
    @State private var sortOrder = [KeyPathComparator<FileItem>(\FileItem.name)]

    private var isActive: Bool { appViewModel.activePanelID == panel.id }

    private var sortedItems: [FileItem] { panel.items.sorted(using: sortOrder) }

    private var groupedItems: [(String, [FileItem])] {
        let grouped = Dictionary(grouping: panel.items, by: \.fileGroupName)
        let priority = ["폴더","이미지","동영상","오디오","문서","코드","압축·설치","텍스트","앱","폰트"]
        var result: [(String, [FileItem])] = []
        for key in priority {
            if let items = grouped[key], !items.isEmpty {
                result.append((key, items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }))
            }
        }
        for key in grouped.keys.sorted() where !priority.contains(key) {
            if let items = grouped[key], !items.isEmpty {
                result.append((key, items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }))
            }
        }
        return result
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            pathBar
            Divider()
            panelContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Rectangle().stroke(Color.green, lineWidth: isDropTargeted ? 3 : 0))
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let destURL = panel.currentURL else { return false }
            for provider in providers {
                _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                    guard let url = object as? URL, url.isFileURL else { return }
                    DispatchQueue.main.async {
                        appViewModel.completeDrop(sourceURL: url, to: destURL, destinationPanel: panel)
                    }
                }
            }
            return true
        }
        .background(keyboardShortcutOverlay)
    }

    // MARK: - Keyboard Shortcuts (hidden overlay, active panel only)

    private var keyboardShortcutOverlay: some View {
        Group {
            // Cmd+C — 선택 파일 복사
            Button("") {
                let urls = sortedItems.filter { selection.contains($0.id) }.map(\.url)
                guard !urls.isEmpty else { return }
                appViewModel.copyFiles(urls)
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!isActive || selection.isEmpty)

            // Cmd+V — 현재 폴더에 붙여넣기
            Button("") {
                guard let dir = panel.currentURL else { return }
                appViewModel.pasteFiles(to: dir, panel: panel)
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(!isActive || panel.currentURL == nil)

            // Cmd+Delete — 휴지통으로 이동
            Button("") {
                sortedItems.filter { selection.contains($0.id) }
                    .forEach { appViewModel.moveToTrash($0.url, panel: panel) }
                selection = []
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(!isActive || selection.isEmpty)
        }
        .opacity(0)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 6) {
            HStack(spacing: 0) {
                Button { panel.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(hoverBack && panel.canGoBack
                                      ? Color.primary.opacity(0.1)
                                      : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(panel.canGoBack ? .primary : Color(NSColor.tertiaryLabelColor))
                .disabled(!panel.canGoBack)
                .onHover { hoverBack = $0 }

                Button { panel.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(hoverForward && panel.canGoForward
                                      ? Color.primary.opacity(0.1)
                                      : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(panel.canGoForward ? .primary : Color(NSColor.tertiaryLabelColor))
                .disabled(!panel.canGoForward)
                .onHover { hoverForward = $0 }
            }
            .background(Color(NSColor.controlBackgroundColor).cornerRadius(6))

            Image(systemName: isActive ? "folder.fill" : "folder")
                .foregroundColor(isActive ? .accentColor : .secondary)
                .font(.caption)

            Text(panel.currentURL?.lastPathComponent ?? "비어있음")
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if panel.currentURL != nil {
                Button {
                    groupByExtension.toggle()
                } label: {
                    Image(systemName: groupByExtension ? "square.grid.2x2.fill" : "square.grid.2x2")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(groupByExtension ? .accentColor : .secondary)
                .help(groupByExtension ? "목록 보기" : "확장자별 그룹 보기")

                Button { panel.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button { openFolderPanel() } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isActive ? Color.accentColor.opacity(0.12) : Color(NSColor.windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture { activate() }
    }

    // MARK: - Path bar

    @ViewBuilder
    private var pathBar: some View {
        if let url = panel.currentURL {
            Text(url.path)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .contentShape(Rectangle())
                .onTapGesture { activate() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var panelContent: some View {
        if panel.currentURL == nil {
            emptyPlaceholder
        } else if panel.items.isEmpty {
            emptyFolder
        } else if groupByExtension {
            extensionGroupedView
        } else {
            tableView
        }
    }

    // MARK: - Table view

    private var tableView: some View {
        Table(sortedItems, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("이름", value: \FileItem.name) { (item: FileItem) in
                HStack(spacing: 6) {
                    Image(nsImage: icon(for: item))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
                    Text(item.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .onTapGesture(count: 2) { handleOpen(item) }
                .onDrag { dragProvider(for: item) }
            }

            TableColumn("확장자", value: \FileItem.fileExtension) { (item: FileItem) in
                Text(item.isDirectory ? "폴더" : (item.fileExtension.isEmpty ? "—" : item.fileExtension))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .onDrag { dragProvider(for: item) }
            }
            .width(min: 40, ideal: 60, max: 90)

            TableColumn("수정일", value: \FileItem.sortDate) { (item: FileItem) in
                Text(item.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .onDrag { dragProvider(for: item) }
            }
            .width(min: 80, ideal: 130)

            TableColumn("크기", value: \FileItem.sortSize) { (item: FileItem) in
                Text(item.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .onDrag { dragProvider(for: item) }
            }
            .width(min: 50, ideal: 70)
        }
        .onChange(of: selection) { _ in activate() }
        .contextMenu(forSelectionType: UUID.self) { ids in
            tableContextMenu(for: ids)
        }
    }

    private func dragProvider(for item: FileItem) -> NSItemProvider {
        appViewModel.startDrag(item: item, fromPanelID: panel.id,
                               selection: selection, allItems: sortedItems)
        return NSItemProvider(object: item.url as NSURL)
    }

    // MARK: - Extension grouped view

    private var extensionGroupedView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedItems, id: \.0) { groupName, items in
                    Section {
                        ForEach(items) { item in
                            HStack(spacing: 6) {
                                Image(nsImage: icon(for: item))
                                    .resizable().interpolation(.high)
                                    .frame(width: 16, height: 16)
                                    .frame(width: 32)
                                Text(item.name)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text(item.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 130, alignment: .leading)
                                Text(item.formattedSize)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture(count: 2).onEnded { handleOpen(item) }
                                    .exclusively(before: TapGesture(count: 1).onEnded {
                                        appViewModel.activatePanel(panel)
                                    })
                            )
                            .onDrag {
                                appViewModel.startDrag(item: item, fromPanelID: panel.id,
                                                       selection: [item.id], allItems: [item])
                                return NSItemProvider(object: item.url as NSURL)
                            }
                            .contextMenu {
                                groupedItemContextMenu(for: item)
                            }
                            Divider().padding(.leading, 40)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Text(groupName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("(\(items.count))")
                                .font(.system(size: 10))
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            }
        }
        .contextMenu {
            backgroundContextMenuContent
        }
    }

    // MARK: - Context Menus

    /// 테이블 뷰 우클릭 메뉴 (선택 항목 없으면 배경 메뉴)
    @ViewBuilder
    private func tableContextMenu(for ids: Set<UUID>) -> some View {
        if ids.isEmpty {
            backgroundContextMenuContent
        } else {
            let items = sortedItems.filter { ids.contains($0.id) }
            if items.count == 1, let item = items.first {
                Button("열기") { handleOpen(item) }
                Button("Finder에서 보기") { appViewModel.revealInFinder(item.url) }
                Divider()
                Button("복사") { appViewModel.copyFiles([item.url]) }
                Button("복제") { appViewModel.duplicateFile(item.url, panel: panel) }
                Button("이름 변경") { appViewModel.showRenameDialog(for: item.url, panel: panel) }
                Divider()
                Button("휴지통으로 이동", role: .destructive) {
                    appViewModel.moveToTrash(item.url, panel: panel)
                    selection = []
                }
            } else {
                Button("\(items.count)개 항목 열기") { items.forEach { handleOpen($0) } }
                Divider()
                Button("복사") { appViewModel.copyFiles(items.map(\.url)) }
                Divider()
                Button("휴지통으로 이동 (\(items.count)개)", role: .destructive) {
                    items.forEach { appViewModel.moveToTrash($0.url, panel: panel) }
                    selection = []
                }
            }
        }
    }

    /// 그룹 뷰 개별 행 우클릭 메뉴
    @ViewBuilder
    private func groupedItemContextMenu(for item: FileItem) -> some View {
        Button("열기") { handleOpen(item) }
        Button("Finder에서 보기") { appViewModel.revealInFinder(item.url) }
        Divider()
        Button("복사") { appViewModel.copyFiles([item.url]) }
        Button("복제") { appViewModel.duplicateFile(item.url, panel: panel) }
        Button("이름 변경") { appViewModel.showRenameDialog(for: item.url, panel: panel) }
        Divider()
        Button("휴지통으로 이동", role: .destructive) {
            appViewModel.moveToTrash(item.url, panel: panel)
        }
    }

    /// 빈 공간 우클릭 메뉴 (테이블/그룹뷰 공통)
    @ViewBuilder
    private var backgroundContextMenuContent: some View {
        if let dir = panel.currentURL {
            Button("새 폴더") {
                appViewModel.showNewFolderDialog(in: dir, panel: panel)
            }
            if appViewModel.hasPasteboardFiles() {
                Button("붙여넣기") {
                    appViewModel.pasteFiles(to: dir, panel: panel)
                }
            }
            Divider()
            Button("새로고침") { panel.refresh() }
        }
    }

    // MARK: - Placeholders

    private var emptyPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 44)).foregroundColor(.secondary)
            Text("폴더를 선택하세요").font(.headline).foregroundColor(.secondary)
            Text("사이드바에서 폴더를 클릭하거나\n아래 버튼으로 직접 열어보세요")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("폴더 열기") {
                appViewModel.activatePanel(panel)
                openFolderPanel()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            backgroundContextMenuContent
        }
    }

    private var emptyFolder: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 36)).foregroundColor(.secondary)
            Text("비어있는 폴더").foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            backgroundContextMenuContent
        }
    }

    // MARK: - Activation

    private func activate() {
        appViewModel.activatePanel(panel)
    }

    // MARK: - Helpers

    private func handleOpen(_ item: FileItem) {
        if item.isDirectory { panel.navigate(to: item.url) }
        else { NSWorkspace.shared.open(item.url) }
    }

private func icon(for item: FileItem) -> NSImage {
        if item.isDirectory { return NSWorkspace.shared.icon(for: .folder) }
        if !item.fileExtension.isEmpty,
           let uti = UTType(filenameExtension: item.fileExtension) {
            return NSWorkspace.shared.icon(for: uti)
        }
        return NSWorkspace.shared.icon(forFile: item.url.path)
    }

    private func openFolderPanel() {
        let op = NSOpenPanel()
        op.canChooseFiles = false
        op.canChooseDirectories = true
        op.allowsMultipleSelection = false
        op.message = "열 폴더를 선택하세요"
        op.prompt = "열기"
        if let current = panel.currentURL { op.directoryURL = current }
        guard op.runModal() == .OK, let url = op.url else { return }
        appViewModel.activatePanel(panel)
        panel.navigate(to: url)
    }
}


#Preview("빈 패널") {
    let vm = AppViewModel()
    let panel = vm.panels[0]
    return SinglePanelView(panel: panel)
        .environmentObject(vm)
        .frame(width: 500, height: 500)
}

#Preview("다운로드 폴더") {
    let vm = AppViewModel()
    let panel = vm.panels[0]
    panel.navigate(to: URL(fileURLWithPath: NSHomeDirectory() + "/Downloads"))
    return SinglePanelView(panel: panel)
        .environmentObject(vm)
        .frame(width: 500, height: 500)
}
