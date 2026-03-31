# 파일 표시 복구 + 드래그/선택/이동 전면 재정비 핸드오프

> 작성일: 2026년 3월 31일 | Phase 5 이후 — SwiftUI Table 파일 미표시 버그 수정 + 드래그 UX 재설계

---

## 작업 요약

post3에서 도입한 `TableDragProxy`(NSTableViewDataSource 교체 방식)가 파일 목록을 전혀 표시하지 않는 버그를 유발했다.
원인을 파악하고 구조를 전면 교체했으며, 드래그/선택/이동 UX를 사용자 요구에 맞게 재설계했다.
빌드는 **BUILD SUCCEEDED** 상태.

---

## 근본 원인 분석

### TableDragProxy가 파일 표시를 막은 이유

post3 방식: `tv.dataSource = TableDragProxy(original: swiftUIDataSource, ...)` 로 SwiftUI Table 내부 dataSource를 교체.

SwiftUI의 `Table`은 내부적으로 `NSTableViewDiffableDataSource`(또는 유사한 메커니즘)를 dataSource로 사용한다.
`tv.dataSource`가 교체되면 SwiftUI는 자신이 dataSource의 주도권을 잃었다고 판단하고
새 데이터(panel.items 변경) 적용을 중단 → **파일 목록이 전혀 표시되지 않음**.

### 해결 방향

**dataSource를 교체하지 않는다.** 드래그는 SwiftUI `.onDrag`로 처리(SwiftUI `.onDrop`과 완벽 연동).
선택은 NSEvent mouseDown 모니터로 NSTableView에 직접 강제 적용.

---

## 최종 구조 (현재 상태)

### 핵심 원칙

```
dataSource 교체 없음 → SwiftUI Table 렌더링 완전 보존
선택: NSEvent leftMouseDown 모니터 → tv.selectRowIndexes 강제
더블클릭: NSEvent clickCount==2 감지 → handleOpen 직접 호출
드래그: 셀 .onDrag → SwiftUI .onDrop 연동 → 파일 이동
```

### 변경된 파일

**`Views/SinglePanelView.swift`** 전체 tableView 섹션 + 하단 헬퍼 구조체

---

## TableSetup 현재 구조

```
TableSetup (NSViewRepresentable)
├── makeNSView: NSView()
├── updateNSView:
│   ├── coordinator.onDoubleClick / items 갱신
│   └── async: findNearestTableView → tv.target/doubleAction 설정
│          + leftMouseDown NSEvent 모니터 설치 (1회)
├── dismantleNSView: 이벤트 모니터 제거
├── findNearestTableView: 윈도우 전체 NSTableView 중 최근접 선택
└── Coordinator:
    ├── rowDoubleClicked → (더블클릭은 handleMouseDown에서 처리)
    └── handleMouseDown(event:)
        ├── clickCount == 2 → onDoubleClick 직접 호출
        ├── Cmd+클릭 → toggle 선택
        ├── Shift+클릭 → 범위 선택
        ├── 이미 선택된 row 클릭 → selection 유지 (드래그 대비)
        └── 일반 클릭 → 단일 선택
```

---

## 드래그/선택 UX 규칙

| 행 상태 | 클릭 영역 | 동작 |
|---|---|---|
| 미선택 | 텍스트/아이콘 | 파일이동 드래그 가능 |
| 미선택 | 여백(Spacer 등) | 드래그 없음 (클릭 → 선택만) |
| 선택됨 | 어디서든 | 파일이동 드래그 가능 |

### 구현 방법: `ContentShapeIfSelected` ViewModifier

```swift
private struct ContentShapeIfSelected: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        if selected {
            content.contentShape(Rectangle())  // 전체 너비 히트테스트
        } else {
            content  // 텍스트/아이콘 영역만 히트테스트
        }
    }
}
```

- 선택된 행: `.contentShape(Rectangle())` → Spacer 포함 전체 너비 드래그 가능
- 미선택 행: contentShape 없음 → 텍스트/아이콘만 히트테스트 → 여백은 드래그 불가

### 다중 파일 드래그 보장

이미 선택된 row 클릭 시 selection 유지 로직:
```swift
} else if tv.selectedRowIndexes.contains(row) {
    return  // selection 그대로 유지 → .onDrag에서 panel.selectedIDs 전체가 pendingDragURLs에 세팅됨
}
```

---

## 키보드 단축키 변경

| 단축키 | 이전 | 현재 |
|---|---|---|
| Return | 폴더만 진입 | 폴더 진입 + 파일 앱으로 열기 (`handleOpen` 공통 사용) |

---

## .onDrag 적용 범위

모든 4개 컬럼(이름, 확장자, 수정일, 크기) 셀에 `.onDrag` 적용.
각 셀은 `ContentShapeIfSelected`로 선택 여부에 따라 히트 영역 결정.

---

## 제거된 구조

- `TableDragProxy` (NSTableViewDataSource 프록시) — 완전 삭제
- `NSDraggingSource` / `beginDraggingSession` 방식 — 폐기
  - 이유: AppKit 드래그는 SwiftUI `.onDrop`과 호환 안됨

---

## 주의사항 / 다음 세션 확인 사항

1. **SourceKit 오류**: `Cannot find type 'FileItem' in scope` 등 — 빌드 성공하므로 IDE 재인덱싱(Cmd+Shift+K 후 재빌드)으로 해결.

2. **더블클릭 처리**: NSTableView `doubleAction`은 `.onDrag`가 mouseDown을 가로채서 작동 안함.
   NSEvent 모니터의 `clickCount == 2`로 대신 처리함.

3. **그룹 뷰(extensionGroupedView)**: 별도로 `.onDrag` 구현되어 있으며 이번 변경 영향 없음.

4. **파일 이동 흐름**:
   ```
   .onDrag 실행 → appViewModel.startDrag → pendingDragURLs 설정
   → 대상 패널에 드롭 → .onDrop → completeDrop → FileManager.moveItem
   → 양쪽 패널 refresh()
   ```

---

## 빌드 상태

```
** BUILD SUCCEEDED **
```

Scheme: `Folder Flow`, Configuration: `Debug`
