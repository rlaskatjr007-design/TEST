# 클릭 선택 + 드래그 + UX 개선 핸드오프

> 작성일: 2026년 3월 30일 | Phase 5 이후 — SwiftUI Table 클릭·드래그 근본 수정 세션

---

## 작업 요약

SwiftUI `Table`에서 파일 아이콘/텍스트를 클릭해도 하이라이트가 표시되지 않는 문제,
더블클릭 폴더 진입 불안정, 파일 드래그 이동 등을 근본적으로 수정했다.
빌드는 **BUILD SUCCEEDED** 상태.

---

## 근본 원인 분석

### `.onDrag`가 클릭 선택을 막은 이유

SwiftUI `Table` 셀에 `.onDrag`를 붙이면:
- SwiftUI가 해당 셀의 `NSHostingView`를 `mouseDown` 이벤트 캡처 상태로 만든다
- `NSHostingView`가 mouseDown을 먼저 가져가므로 `NSTableView`에 이벤트가 전달되지 않음
- `NSTableView`가 selection을 처리하지 못해 **하이라이트가 표시되지 않음**
- `Spacer()`는 AppKit backing view가 없어서 mouseDown이 통과 → 빈 공간 클릭만 동작

### 시도했다가 실패한 접근들

| 접근 | 실패 이유 |
|---|---|
| `simultaneousGesture(TapGesture(count:2))` 제거만 | `.onDrag`가 여전히 NSHostingView 캡처 |
| `contentShape(Rectangle())` 추가 | HStack 전체가 SwiftUI hit-test 대상 → 더 악화 |
| `allowsHitTesting(false)` on HStack | drag와 confliclt, 불가 |
| per-cell `TableDoubleClickHandler` | 다중 coordinator 충돌, drag 없음 |
| `NSPanGestureRecognizer` | 클릭 시 드래그 모션 발생, 파일 미이동 |
| `NSEvent` 로컬 모니터 + `beginDraggingSession` | 이벤트 처리 중 재진입 문제로 드래그 불안정 |

---

## 최종 구조 (현재 상태)

### 핵심 원칙

```
셀에 gesture/onDrag 없음 → NSTableView 네이티브 selection 완전 위임
더블클릭/드래그는 NSTableViewDataSource 레벨에서 처리 (TableSetup + TableDragProxy)
```

### 변경된 파일

**`Views/SinglePanelView.swift`** 전체 tableView 섹션 + 하단 헬퍼 구조체

---

## tableView 현재 상태

```swift
private var tableView: some View {
    Table(sortedItems, selection: $panel.selectedIDs, sortOrder: $sortOrder) {
        TableColumn("이름", value: \FileItem.name) { (item: FileItem) in
            HStack(spacing: 6) {
                Image(nsImage: icon(for: item))
                    .resizable().interpolation(.high).frame(width: 16, height: 16)
                Text(item.name)
                    .font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                Spacer()
            }
            // .onDrag 없음 — NSHostingView mouseDown 캡처 방지
        }
        TableColumn("확장자") { ... }   // .onDrag 없음
        TableColumn("수정일") { ... }   // .onDrag 없음
        TableColumn("크기") { ... }     // .onDrag 없음
    }
    .onChange(of: panel.selectedIDs) { newSelection in
        if !newSelection.isEmpty { activate() }
    }
    .contextMenu(forSelectionType: UUID.self) { ids in tableContextMenu(for: ids) }
    .background(
        TableSetup(
            items: sortedItems,
            selectedIDs: panel.selectedIDs,
            onDoubleClick: handleOpen,
            onStartDrag: { item, sel, all in
                appViewModel.startDrag(item: item, fromPanelID: panel.id,
                                       selection: sel, allItems: all)
            }
        )
    )
}
```

---

## TableSetup / TableDragProxy 구조

```
TableSetup (NSViewRepresentable)
├── makeNSView: NSView()
├── updateNSView:
│   ├── coordinator.onDoubleClick 갱신
│   ├── proxy 있으면 items/selectedIDs/onStartDrag 갱신
│   └── async: findNearestTableView → tv.target/doubleAction 설정
│          + proxy == nil이면 TableDragProxy 설치 (1회만)
├── dismantleNSView: 원래 dataSource 복원
├── findNearestTableView:
│   └── 윈도우 전체 NSTableView 수집 → nsView 조상 체인과 거리 비교 → 최근접 선택
│       (SwiftUI 내부 wrapper 때문에 직접 형제 탐색 불가)
└── Coordinator:
    ├── rowDoubleClicked(_:) → onDoubleClick
    └── proxy: TableDragProxy (weak installedTableView)

TableDragProxy (NSTableViewDataSource)
├── original: 원래 dataSource (강참조, 위임용)
├── numberOfRows/objectValueFor/... → original에 위임
├── pasteboardWriterForRow(row:) → items[row].url as NSURL  ← 드래그 핵심
└── draggingSession willBeginAt → onStartDrag 호출 (pendingDragURLs 설정)
```

### 드래그 흐름

```
사용자 드래그 시작
  → NSTableView 자체 감지 (mouseDown + mouseDragged)
  → pasteboardWriterForRow(row:) 호출 → NSURL 반환
  → draggingSession willBeginAt → appViewModel.startDrag (pendingDragURLs 설정)
  → 사용자 대상 패널에 드롭
  → SinglePanelView.body .onDrop → completeDrop → 파일 이동
```

---

## 이번 세션 추가 기능

| 기능 | 구현 위치 |
|---|---|
| 폴더 선택 후 **Return키** → 폴더 진입 | `keyboardShortcutOverlay` — `.keyboardShortcut(.return, modifiers: [])` |
| 헤더 **새로고침 버튼 제거** | `panelHeader`에서 `arrow.clockwise` Button 삭제 |

---

## 주의사항 / 다음 세션 확인 사항

1. **TableDragProxy 설치 타이밍**: `DispatchQueue.main.async`로 지연 설치되므로 앱 첫 로드 시 `nsView.window`가 nil일 경우 재시도됨 (다음 render에서 updateNSView 재호출 → 설치됨).

2. **파일 드래그 미이동 시 확인 포인트**:
   - `draggingSession willBeginAt`에서 `onStartDrag`가 호출되는지
   - `AppViewModel.pendingDragURLs`가 설정되는지
   - `.onDrop(of: [UTType.fileURL])`에서 `completeDrop` 진입 여부

3. **그룹 뷰(extensionGroupedView)의 드래그**: 현재 `.onDrag` 없음 — 그룹 뷰에서 드래그가 필요하면 별도 구현 필요.

4. **SourceKit 오류**: `Cannot find type 'FileItem' in scope` 등 — 빌드는 성공하므로 IDE 재인덱싱으로 해결 (Cmd+Shift+K 후 재빌드).

---

## 빌드 상태

```
** BUILD SUCCEEDED **
```

Scheme: `Folder Flow`, Configuration: `Debug`
