import SwiftUI
import Combine
import UniformTypeIdentifiers
import AppKit
import Quartz

struct SinglePanelView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var panel: PanelState
    @State private var isDropTargeted = false
    @State private var groupByExtension = false
    @State private var hoverBack = false
    @State private var hoverForward = false
    @State private var sortOrder = [KeyPathComparator<FileItem>(\FileItem.name)]

    private var isActive: Bool { appViewModel.activePanelID == panel.id }

    private var sortedItems: [FileItem] { panel.items.sorted(using: sortOrder) }

    private var selectedURLs: [URL] {
        panel.items.filter { panel.selectedIDs.contains($0.id) }.map(\.url)
    }

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
        .background(QuickLookHelper(selectedURLs: selectedURLs, isActive: isActive))
    }

    // MARK: - Keyboard Shortcuts (hidden overlay, active panel only)

    private var keyboardShortcutOverlay: some View {
        Group {
            // Cmd+C — 선택 파일 복사
            Button("") {
                let urls = sortedItems.filter { panel.selectedIDs.contains($0.id) }.map(\.url)
                guard !urls.isEmpty else { return }
                appViewModel.copyFiles(urls)
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!isActive || panel.selectedIDs.isEmpty)

            // Cmd+V — 현재 폴더에 붙여넣기
            Button("") {
                guard let dir = panel.currentURL else { return }
                appViewModel.pasteFiles(to: dir, panel: panel)
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(!isActive || panel.currentURL == nil)

            // Cmd+Delete — 휴지통으로 이동
            Button("") {
                sortedItems.filter { panel.selectedIDs.contains($0.id) }
                    .forEach { appViewModel.moveToTrash($0.url, panel: panel) }
                panel.selectedIDs = []
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(!isActive || panel.selectedIDs.isEmpty)

            // Return — 선택 항목 열기 (폴더: 진입 / 파일: 앱으로 열기)
            Button("") {
                guard let item = sortedItems.first(where: { panel.selectedIDs.contains($0.id) }) else { return }
                handleOpen(item)
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(!isActive || panel.selectedIDs.isEmpty)
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
        Table(sortedItems, selection: $panel.selectedIDs, sortOrder: $sortOrder) {
            // .onDrag는 SwiftUI .onDrop과 완벽 연동됨 (AppKit beginDraggingSession은 .onDrop과 호환 안됨)
            // mouseDown 선택은 TableSetup NSEvent 모니터가 NSTableView에 강제 적용
            TableColumn("이름", value: \FileItem.name) { (item: FileItem) in
                // 선택된 행: Spacer 포함 전체 너비 드래그 가능 (contentShape)
                // 미선택 행: 아이콘+텍스트 영역만 드래그 가능 (여백은 드래그 불가)
                let isSelected = panel.selectedIDs.contains(item.id)
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
                .frame(maxWidth: .infinity)
                .modifier(ContentShapeIfSelected(selected: isSelected))
                .onDrag {
                    let sel = isSelected ? panel.selectedIDs : [item.id]
                    appViewModel.startDrag(item: item, fromPanelID: panel.id,
                                           selection: sel, allItems: sortedItems)
                    return NSItemProvider(object: item.url as NSURL)
                }
            }

            TableColumn("확장자", value: \FileItem.fileExtension) { (item: FileItem) in
                let isSelected = panel.selectedIDs.contains(item.id)
                Text(item.isDirectory ? "폴더" : (item.fileExtension.isEmpty ? "—" : item.fileExtension))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(ContentShapeIfSelected(selected: isSelected))
                    .onDrag {
                        let sel = isSelected ? panel.selectedIDs : [item.id]
                        appViewModel.startDrag(item: item, fromPanelID: panel.id,
                                               selection: sel, allItems: sortedItems)
                        return NSItemProvider(object: item.url as NSURL)
                    }
            }
            .width(min: 40, ideal: 60, max: 90)

            TableColumn("수정일", value: \FileItem.sortDate) { (item: FileItem) in
                let isSelected = panel.selectedIDs.contains(item.id)
                Text(item.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(ContentShapeIfSelected(selected: isSelected))
                    .onDrag {
                        let sel = isSelected ? panel.selectedIDs : [item.id]
                        appViewModel.startDrag(item: item, fromPanelID: panel.id,
                                               selection: sel, allItems: sortedItems)
                        return NSItemProvider(object: item.url as NSURL)
                    }
            }
            .width(min: 80, ideal: 130)

            TableColumn("크기", value: \FileItem.sortSize) { (item: FileItem) in
                let isSelected = panel.selectedIDs.contains(item.id)
                Text(item.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(ContentShapeIfSelected(selected: isSelected))
                    .onDrag {
                        let sel = isSelected ? panel.selectedIDs : [item.id]
                        appViewModel.startDrag(item: item, fromPanelID: panel.id,
                                               selection: sel, allItems: sortedItems)
                        return NSItemProvider(object: item.url as NSURL)
                    }
            }
            .width(min: 50, ideal: 70)
        }
        .onChange(of: panel.selectedIDs) { newSelection in
            if !newSelection.isEmpty { activate() }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            tableContextMenu(for: ids)
        }
        .background(
            TableSetup(items: sortedItems, onDoubleClick: handleOpen)
        )
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
                            .background(
                                panel.selectedIDs.contains(item.id)
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture(count: 2).onEnded { handleOpen(item) }
                                    .exclusively(before: TapGesture(count: 1).onEnded {
                                        panel.selectedIDs = [item.id]
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
                    panel.selectedIDs = []
                }
            } else {
                Button("\(items.count)개 항목 열기") { items.forEach { handleOpen($0) } }
                Divider()
                Button("복사") { appViewModel.copyFiles(items.map(\.url)) }
                Divider()
                Button("휴지통으로 이동 (\(items.count)개)", role: .destructive) {
                    items.forEach { appViewModel.moveToTrash($0.url, panel: panel) }
                    panel.selectedIDs = []
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
        // NSTableView doubleAction 경로: selection은 NSTableView가 이미 설정
        // 그룹 뷰 경로: 호출 전에 selection을 수동으로 설정함
        if item.isDirectory {
            panel.navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
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



// MARK: - NSTableView 더블클릭 + 선택 헬퍼
//
// [더블클릭] NSTableView.doubleAction selector
// [선택]     .onDrag가 NSHostingView mouseDown을 캡처해 NSTableView가 row를 못 선택하므로
//            NSEvent 로컬 모니터로 mouseDown을 감지, NSTableView에 직접 selectRowIndexes 강제 적용
// [드래그]   셀의 .onDrag가 처리 (SwiftUI .onDrop과 완벽 연동)
//
// findNearestTableView: SwiftUI 내부 wrapper 때문에 직접 형제 탐색이 실패하므로
// 윈도우 전체 NSTableView 중 공통 조상 거리가 가장 가까운 것을 선택.
private struct TableSetup: NSViewRepresentable {
    var items: [FileItem]
    var onDoubleClick: (FileItem) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDoubleClick = onDoubleClick
        context.coordinator.items = items

        DispatchQueue.main.async {
            guard let tv = TableSetup.findNearestTableView(from: nsView) else { return }
            tv.target = context.coordinator
            tv.doubleAction = #selector(Coordinator.rowDoubleClicked(_:))

            guard context.coordinator.eventMonitor == nil else { return }
            context.coordinator.tableView = tv

            let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak coord = context.coordinator] event in
                coord?.handleMouseDown(event: event)
                return event
            }
            context.coordinator.eventMonitor = monitor
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.eventMonitor {
            NSEvent.removeMonitor(monitor)
            coordinator.eventMonitor = nil
        }
    }

    private static func findNearestTableView(from nsView: NSView) -> NSTableView? {
        guard let root = nsView.window?.contentView else { return nil }
        var all: [NSTableView] = []
        collectTableViews(in: root, into: &all)
        guard !all.isEmpty else { return nil }
        var ancestors = [ObjectIdentifier: Int]()
        var v: NSView? = nsView; var depth = 0
        while let cur = v { ancestors[ObjectIdentifier(cur)] = depth; v = cur.superview; depth += 1 }
        var best: NSTableView? = nil; var bestDist = Int.max
        for tv in all {
            var u: NSView? = tv; var d = 0
            while let cur = u {
                if let ad = ancestors[ObjectIdentifier(cur)] {
                    let total = d + ad
                    if total < bestDist { bestDist = total; best = tv }
                    break
                }
                u = cur.superview; d += 1
            }
        }
        return best
    }

    private static func collectTableViews(in view: NSView, into result: inout [NSTableView]) {
        if let tv = view as? NSTableView { result.append(tv); return }
        for sub in view.subviews { collectTableViews(in: sub, into: &result) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var onDoubleClick: ((FileItem) -> Void)?
        var items: [FileItem] = []
        weak var tableView: NSTableView?
        var eventMonitor: Any?

        @objc func rowDoubleClicked(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0, row < items.count else { return }
            onDoubleClick?(items[row])
        }

        func handleMouseDown(event: NSEvent) {
            guard let tv = tableView else { return }
            let location = tv.convert(event.locationInWindow, from: nil)
            let row = tv.row(at: location)
            guard row >= 0 else { return }

            // 더블클릭: .onDrag가 mouseDown을 캡처해 doubleAction이 안 울리므로 직접 처리
            if event.clickCount == 2 {
                guard row < items.count else { return }
                onDoubleClick?(items[row])
                return
            }

            // 단일클릭: .onDrag가 mouseDown을 가로채므로 NSTableView에 직접 선택 강제
            let flags = event.modifierFlags
            if flags.contains(.command) {
                var sel = tv.selectedRowIndexes
                if sel.contains(row) { sel.remove(row) } else { sel.insert(row) }
                tv.selectRowIndexes(sel, byExtendingSelection: false)
            } else if flags.contains(.shift), let anchor = tv.selectedRowIndexes.first {
                let range = min(anchor, row)...max(anchor, row)
                tv.selectRowIndexes(IndexSet(range), byExtendingSelection: false)
            } else if tv.selectedRowIndexes.contains(row) {
                // 이미 선택된 row 클릭 → selection 유지 (드래그 시작 가능성)
                return
            } else {
                tv.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
    }
}

// MARK: - ContentShape 조건부 적용
// 선택된 행: Rectangle()로 전체 너비(여백 포함) 히트테스트 → 어디서든 드래그 가능
// 미선택 행: contentShape 없음 → 텍스트/아이콘 영역만 히트테스트 → 여백은 드래그 불가
private struct ContentShapeIfSelected: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        if selected {
            content.contentShape(Rectangle())
        } else {
            content
        }
    }
}

// MARK: - Quick Look Helper
//
// 스페이스바(keyCode 49) 감지 → QLPreviewPanel 열기/닫기
// 활성 패널에서만 동작하며, 선택 파일이 바뀌면 패널 내용도 자동 갱신
private struct QuickLookHelper: NSViewRepresentable {
    var selectedURLs: [URL]
    var isActive: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.selectedURLs = selectedURLs
        context.coordinator.isActive = isActive

        // 패널이 열려 있고 내가 데이터소스라면 선택 변경 즉시 반영
        if QLPreviewPanel.sharedPreviewPanelExists() {
            let panel = QLPreviewPanel.shared()!
            if panel.isVisible, panel.dataSource === context.coordinator {
                panel.reloadData()
            }
        }

        guard context.coordinator.keyMonitor == nil else { return }
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coord = context.coordinator] event in
            guard let coord = coord, coord.isActive else { return event }
            if event.keyCode == 49 { // spacebar
                coord.toggleQuickLook()
                return nil // 이벤트 소비 (다른 뷰로 전달 안 함)
            }
            return event
        }
        context.coordinator.keyMonitor = monitor
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.keyMonitor {
            NSEvent.removeMonitor(monitor)
            coordinator.keyMonitor = nil
        }
        if QLPreviewPanel.sharedPreviewPanelExists() {
            let panel = QLPreviewPanel.shared()!
            if panel.dataSource === coordinator { panel.orderOut(nil) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, QLPreviewPanelDataSource {
        var selectedURLs: [URL] = []
        var isActive: Bool = false
        var keyMonitor: Any?

        func toggleQuickLook() {
            let panel = QLPreviewPanel.shared()!
            if panel.isVisible {
                panel.orderOut(nil)
            } else {
                guard !selectedURLs.isEmpty else { return }
                panel.dataSource = self
                panel.reloadData()
                panel.makeKeyAndOrderFront(nil)
            }
        }

        // MARK: QLPreviewPanelDataSource
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            selectedURLs.count
        }
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            selectedURLs[index] as NSURL
        }
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
