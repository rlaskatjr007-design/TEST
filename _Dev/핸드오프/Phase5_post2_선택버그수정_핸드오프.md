# 선택(하이라이트) 버그 수정 핸드오프

> 작성일: 2026년 3월 30일 | Phase 5 이후 — 파일 선택 하이라이트 버그 수정 세션

---

## 작업 요약

파일 탐색기 패널의 클릭 선택(하이라이트) 관련 버그를 수정했다.
빌드는 **BUILD SUCCEEDED** 상태이며 SourceKit 오류는 인덱싱 false positive로 실제 컴파일과 무관하다.

---

## 변경된 파일

| 파일 | 변경 내용 |
|---|---|
| `Models/PanelState.swift` | `selectedIDs: Set<UUID>` 추가, `navigate()` 시 selectedIDs 초기화 |
| `ViewModels/AppViewModel.swift` | `activatePanel()` 에서 이전 패널 selectedIDs 초기화 |
| `Views/SinglePanelView.swift` | `@State selection` 제거 → `panel.selectedIDs` 사용, 제스처 정리 |

---

## 핵심 구조 변경

### 이전 구조 (버그 있음)
```swift
// SinglePanelView
@State private var selection: Set<UUID> = []  // 뷰 로컬 상태

// body
.onChange(of: appViewModel.activePanelID) { newID in
    if newID != panel.id { selection = [] }  // 문제: 아래 onChange를 재발동시킴
}

// tableView
.onChange(of: selection) { _ in activate() }  // 문제: selection이 빈값이 될 때도 호출
```

**순환 버그**: 패널2 클릭 → activePanelID 변경 → 패널1 onChange → `selection=[]` → 패널1 onChange(selection) → `activate()` → activePanelID 복원 → 패널2 하이라이트 소멸

### 현재 구조 (수정됨)
```swift
// PanelState
@Published var selectedIDs: Set<UUID> = []  // 모델이 상태 소유

// AppViewModel
func activatePanel(_ panel: PanelState) {
    if let prev = activePanel, prev.id != panel.id {
        prev.selectedIDs = []  // 이전 패널 selection 직접 초기화 (onChange 체인 없음)
    }
    activePanelID = panel.id
}

// SinglePanelView - tableView
Table(sortedItems, selection: $panel.selectedIDs, ...)
    .onChange(of: panel.selectedIDs) { newSelection in
        if !newSelection.isEmpty { activate() }  // 빈값 될 때는 호출 안 함
    }
```

---

## PanelState.swift 현재 상태

```swift
class PanelState: ObservableObject, Identifiable {
    let id = UUID()
    @Published var currentURL: URL?
    @Published var items: [FileItem] = []
    @Published var selectedIDs: Set<UUID> = []   // ← 추가됨
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false

    func navigate(to url: URL) {
        // ... 히스토리 처리 ...
        selectedIDs = []   // ← 추가됨: 폴더 진입 시 선택 초기화
        loadContents()
    }
}
```

---

## AppViewModel.swift 현재 상태 (activatePanel 부분)

```swift
func activatePanel(_ panel: PanelState) {
    if let prev = activePanel, prev.id != panel.id {
        prev.selectedIDs = []
    }
    activePanelID = panel.id
}
```

---

## SinglePanelView.swift 현재 상태

### State 변수
```swift
@State private var isDropTargeted = false
@State private var groupByExtension = false
// @State private var selection 제거됨 → panel.selectedIDs 사용
@State private var hoverBack = false
@State private var hoverForward = false
@State private var sortOrder = [KeyPathComparator<FileItem>(\FileItem.name)]
```

### tableView 제스처 정책
```swift
TableColumn("이름", ...) { item in
    HStack { ... }
        // 더블클릭만 simultaneousGesture 사용
        // 단일클릭은 NSTableView 네이티브 selection에 맡김 (gesture 추가 시 하이라이트 간섭)
        .simultaneousGesture(TapGesture(count: 2).onEnded { handleOpen(item) })
        .onDrag { ... }
}
// 나머지 컬럼(확장자, 수정일, 크기): 제스처 없음
```

### 그룹 뷰 (extensionGroupedView) 선택 처리
```swift
.background(
    panel.selectedIDs.contains(item.id)
        ? Color.accentColor.opacity(0.25)
        : Color.clear
)
.gesture(
    TapGesture(count: 2).onEnded { handleOpen(item) }
        .exclusively(before: TapGesture(count: 1).onEnded {
            panel.selectedIDs = [item.id]
            appViewModel.activatePanel(panel)
        })
)
```

---

## 잔여 이슈 / 다음 세션 확인 사항

- **하이라이트가 여전히 불안정할 가능성**: `simultaneousGesture(TapGesture(count: 2))`가 NSTableView 단일클릭 이벤트에 영향을 줄 수 있음. 증상이 지속되면 이 제스처도 제거하고 NSTableView `doubleAction`을 다시 시도하되, `.background()`가 아닌 TableColumn 내부에 위치시켜야 함.
- **SourceKit 오류**: `Cannot find type 'FileItem' in scope` 등 — 빌드는 성공하므로 IDE 재인덱싱으로 해결 가능 (Cmd+Shift+K 후 재빌드).
- **다중 선택(Shift/Cmd+클릭)**: 현재 `Table` 기본 동작으로 지원되지만 별도 테스트 필요.

---

## 빌드 상태

```
** BUILD SUCCEEDED **
```

Scheme: `Folder Flow`, Configuration: `Debug`
