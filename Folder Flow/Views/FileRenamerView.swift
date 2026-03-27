import SwiftUI
import UniformTypeIdentifiers
import Combine

struct FileRenamerView: View {
    @StateObject private var vm = FileRenamerViewModel()
    @State private var isDropTargeted = false
    @State private var showSearch = false
    @State private var searchText = ""
    @FocusState private var focusedItemID: UUID?

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(minWidth: 320, maxWidth: 400)
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
        .background(
            Button("") { toggleSearch() }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        )
        .onChange(of: focusedItemID) { newID in
            vm.focusedItemID = newID
        }
        .alert("중복된 이름이 있습니다", isPresented: $vm.showDuplicateAlert) {
            Button("확인") { }
        } message: {
            let names = vm.duplicateNameList.map { "• \($0)" }.joined(separator: "\n")
            Text("아래 이름이 중복되어 있습니다.\n이름을 수정한 후 다시 저장하세요.\n\n\(names)")
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            folderHeader
            Divider()
            modePicker
            Divider()
            if vm.items.isEmpty {
                emptyState
            } else {
                fileList
            }
            if let msg = vm.completionMessage {
                Divider()
                completionBanner(msg)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var folderHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundColor(.accentColor)
                .font(.system(size: 14))
            if let url = vm.folderURL {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Button {
                    vm.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("폴더를 드롭하거나 선택하세요")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Spacer()
                Button("폴더 선택") {
                    vm.selectFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var modePicker: some View {
        VStack(spacing: 0) {
            Picker("모드", selection: $vm.mode) {
                Text("일괄 넘버링").tag(RenameMode.batchNumbering)
                Text("개별 이름 변경").tag(RenameMode.individualRename)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if showSearch {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("파일명 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private func toggleSearch() {
        showSearch.toggle()
        if !showSearch { searchText = "" }
    }

    private func matchesSearch(_ item: RenameItem) -> Bool {
        searchText.isEmpty || item.url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            // 전체선택 헤더 (일괄 넘버링 모드에서만 표시)
            if vm.mode == .batchNumbering {
                HStack(spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { vm.allSelected },
                        set: { _ in vm.toggleSelectAll() }
                    )) {
                        Text(vm.allSelected ? "전체 해제" : "전체 선택")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    Spacer()
                    Text("\(vm.selectedCount) / \(vm.items.count)개 선택")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor))
                Divider()
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.items.indices, id: \.self) { index in
                        if matchesSearch(vm.items[index]) {
                            fileRow(index: index)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func fileRow(index: Int) -> some View {
        let item = vm.items[index]
        let binding = Binding(get: { vm.items[index] }, set: { vm.items[index] = $0 })
        return fileRowContent(item: item, binding: binding)
    }

    @ViewBuilder
    private func fileRowContent(item: RenameItem, binding: Binding<RenameItem>) -> some View {
        let isDuplicate = vm.duplicateIDs.contains(item.id)
        let isBatch = vm.mode == .batchNumbering
        let isUnselected = isBatch && !item.isSelected
        let preview = vm.previewName(for: item)
        HStack(spacing: 8) {
            // 체크박스 (일괄 넘버링 모드에서만)
            if isBatch {
                Toggle("", isOn: binding.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            if !item.fileExtension.isEmpty {
                Text(item.fileExtension.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        isDuplicate ? Color.red :
                        (isUnselected ? Color.secondary.opacity(0.4) : Color.accentColor)
                    )
                    .cornerRadius(3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundColor(isDuplicate ? .red.opacity(0.8) : (isUnselected ? .secondary.opacity(0.5) : .secondary))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if isDuplicate {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    Text("→ \(preview)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(
                            isDuplicate ? .red :
                            (isUnselected ? .secondary.opacity(0.4) :
                            (preview == item.url.lastPathComponent ? .primary : .accentColor))
                        )
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isDuplicate ? Color.red.opacity(0.06) : Color.clear)
        .opacity(isUnselected ? 0.6 : 1.0)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text("폴더를 선택하면\n파일 목록이 표시됩니다")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func completionBanner(_ msg: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(msg)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 0) {
            if vm.mode == .batchNumbering {
                batchPanel
            } else {
                individualPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Mode A — 일괄 넘버링

    private var batchPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 설정 영역 (compact)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("기본 이름")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 52, alignment: .trailing)
                    TextField("예: 가맹점사진", text: $vm.baseName)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 8) {
                    Text("번호 설정")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 52, alignment: .trailing)
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Text("시작")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Stepper(value: $vm.startNumber, in: 1...999) {
                                Text("\(vm.startNumber)")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 28)
                            }
                            .controlSize(.small)
                        }
                        Divider().frame(height: 16)
                        HStack(spacing: 2) {
                            pillButton("앞", selected: vm.numberPosition == .prefix) { vm.numberPosition = .prefix }
                            pillButton("뒤", selected: vm.numberPosition == .suffix) { vm.numberPosition = .suffix }
                        }
                        Divider().frame(height: 16)
                        HStack(spacing: 2) {
                            ForEach(NumberPadding.allCases, id: \.self) { pad in
                                pillButton(pad.rawValue, selected: vm.numberPadding == pad) { vm.numberPadding = pad }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // 미리보기 영역 — 항상 표시, 나머지 공간 전체 활용
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(vm.items.isEmpty ? "미리보기" : "미리보기 (\(vm.selectedCount)개 선택)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                if vm.items.isEmpty || vm.baseName.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.page.badge.magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.35))
                        Text(vm.items.isEmpty ? "폴더를 선택하면 미리보기가 표시됩니다" : "기본 이름을 입력하면 미리보기가 표시됩니다")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(vm.items.filter { $0.isSelected }.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(width: 28, alignment: .trailing)
                                    Text(item.url.lastPathComponent)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text(vm.previewName(for: item))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            saveButtons
        }
    }

    // MARK: Mode B — 개별 이름 변경

    private var individualPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 컬럼 헤더
            HStack(spacing: 0) {
                Text("원본 파일명")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                Text("새 이름")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                if !vm.duplicateIDs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text("중복 \(vm.duplicateNameList.count)개")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(.trailing, 16)
                }
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if vm.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("폴더를 먼저 선택하세요")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.items.indices, id: \.self) { index in
                            if matchesSearch(vm.items[index]) {
                                individualRow(index: index)
                                Divider()
                            }
                        }
                    }
                }
            }

            Divider()
            saveButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func individualRow(index: Int) -> some View {
        let item = vm.items[index]
        let isDuplicate = vm.duplicateIDs.contains(item.id)
        let ext = item.fileExtension
        let nameBinding = Binding(
            get: { vm.items[index].customName },
            set: { vm.items[index].customName = $0 }
        )
        return HStack(spacing: 0) {
            // 원본 파일명
            HStack(spacing: 6) {
                if isDuplicate {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                Text(item.url.lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundColor(isDuplicate ? .red.opacity(0.8) : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.horizontal, 8)

            // 새 이름 입력
            HStack(spacing: 4) {
                TextField("새 이름", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedItemID, equals: item.id)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isDuplicate ? Color.red : Color.clear, lineWidth: 1.5)
                    )
                if !ext.isEmpty {
                    Text(".\(ext)")
                        .font(.system(size: 12))
                        .foregroundColor(isDuplicate ? .red : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
        .background(isDuplicate ? Color.red.opacity(0.05) : Color.clear)
    }

    // MARK: - Pill Button

    private func pillButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(selected ? Color.accentColor : Color(NSColor.controlColor))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Buttons

    private var saveButtons: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("별도 저장") {
                vm.saveAsCopy()
            }
            .buttonStyle(.bordered)
            .disabled(vm.items.isEmpty)

            Button("바로 저장") {
                vm.saveInPlace()
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.items.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    FileRenamerView()
}
