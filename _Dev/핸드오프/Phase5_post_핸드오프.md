# Phase 5 이후 수정 핸드오프

> 작성일: 2026년 3월 27일 | Phase 5 완료 후 기능 개선 작업

---

## 변경된 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `Views/SinglePanelView.swift` | 클릭 선택, 정렬, 드래그, hover 전면 개선 |
| `Views/PanelGridView.swift` | 패널 수 [1][2]로 제한 |
| `App/FolderFlowApp.swift` | `WindowGroup("Folder Flow")` 타이틀 명시 |
| `Views/ContentView.swift` | 탭바 우측 앱 브랜딩 추가 |
| `Assets.xcassets/AppIcon.appiconset/` | 앱 아이콘 PNG 10종 생성 및 Contents.json 연결 |

---

## SinglePanelView 현재 상태

### State 변수
```swift
@State private var isDropTargeted = false
@State private var groupByExtension = false
@State private var selection: Set<UUID> = []
@State private var hoverBack = false       // 뒤로가기 hover
@State private var hoverForward = false    // 앞으로가기 hover
@State private var sortOrder = [KeyPathComparator<FileItem>(\FileItem.name)]
```

### 주요 구조 변경 이력

**클릭 선택 수정:**
- body에서 `.simultaneousGesture(TapGesture())` 완전 제거
  → AppKit NSTableView 선택 방해 원인이었음
- Table 선택은 `onChange(of: selection) { _ in activate() }` 로만 처리
- 더블클릭 열기: `.onTapGesture(count: 2)` (이름 컬럼만)

**컬럼 정렬:**
- `Table(sortedItems, selection: $selection, sortOrder: $sortOrder)` 방식
- 각 컬럼에 `value:` 키패스 지정
  - 이름: `\FileItem.name`
  - 확장자: `\FileItem.fileExtension`
  - 수정일: `\FileItem.sortDate` (non-optional Date)
  - 크기: `\FileItem.sortSize` (non-optional Int64)
- `sortedItems`는 `panel.items.sorted(using: sortOrder)` 로 정렬

**드래그:**
- 이름/확장자/수정일/크기 컬럼 모두 `dragProvider(for:)` 공통 함수 사용
- 선택된 아이템 전체를 드래그할 수 있음

**앞/뒤 버튼 hover:**
- `hoverBack` / `hoverForward` @State
- `Color.primary.opacity(0.1)` — 버튼 내부 RoundedRectangle 배경
- 버튼 비활성화 시 hover 배경 미표시
- 그룹 외부 `Color(NSColor.controlBackgroundColor).cornerRadius(6)` 유지

**새로고침 버튼:**
- `frame(width: 24, height: 24)` + `contentShape(Rectangle())` 추가로 탭 영역 확보

**clickFlash 제거:**
- 헤더 깜빡임 원인이었던 `clickFlash` @State 및 애니메이션 완전 제거
- `activate()` 는 `appViewModel.activatePanel(panel)` 단순 호출만

---

## 패널 수 제한
- `PanelGridView`의 버튼 배열을 `[1, 2]`로 변경
- 기본값 `panelCount: Int = 2` (AppViewModel) — 변경 없음

---

## 앱 아이콘
- `/make_icon.swift` 스크립트로 생성 (프로젝트 루트에 보관)
- Retina @2x 문제 → `NSBitmapImageRep` 직접 픽셀 지정 방식으로 해결
- 디자인: 파란 그라디언트 라운드 rect + 흰 폴더 + 우방향 쉐브론 3개

---

## 폴더 크기 표시
- 폴더는 `fileSize = nil` → `formattedSize` 반환값 `"—"`
- macOS Finder와 동일한 동작. 의도된 스펙.

---

## 미사용 파일 (Xcode에서 수동 삭제 권장)
- `ViewModels/FileViewModel.swift`
- `Views/FileRowView.swift`
- `Views/PanelView.swift`
