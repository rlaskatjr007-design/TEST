# Phase 1 핸드오프 — 멀티 패널 + 사이드바

> 완료일: 2026년 3월 | 다음 단계: Phase 2

---

## 완료 내용

### 사이드바 (SidebarView.swift)
- 즐겨찾기 섹션: 바탕화면, 다운로드, 문서, 홈 폴더
- iCloud Drive 섹션 (경로 존재 시 자동 표시)
- 외부 장치 섹션 (`/Volumes` 스캔, 심볼릭 링크 필터로 Macintosh HD 제외)
- 하단 "장치 새로고침" 버튼
- 항목 클릭 → 활성 패널에 폴더 열기 (`openInActivePanel`)
- **사이드바 클릭은 히스토리 초기화** (`resetTo`) — 뒤로가기 비활성화됨 (의도된 동작)

### 패널 시스템 (PanelGridView.swift + SinglePanelView.swift)
- 상단 [1][2][3][4] 버튼으로 패널 수 즉시 변경
- `HSplitView` 기반 네이티브 리사이즈 (AppKit NSSplitView — 흔들림 없음)
- 패널 클릭 시 활성화 → 헤더 파란 강조 (`accentColor.opacity(0.12)`)
- 패널 헤더: 폴더명, 뒤로/앞으로 버튼, 그룹 토글, 새로고침, 폴더 열기

### 파일 목록 (SinglePanelView.swift)
- macOS 네이티브 `Table` 뷰 — 컬럼 리사이즈 지원, 흔들림 없음
- 컬럼: 이름(NSWorkspace 시스템 아이콘), 확장자, 수정일, 크기
- 확장자별 그룹 보기 (⊞ 버튼 토글) — 이미지/동영상/문서/코드 등 섹션 분류
- 폴더 더블클릭 → 해당 패널 안에서 이동 (`navigate`)
- 파일 더블클릭 → `NSWorkspace.shared.open()` 기본 앱 실행
- `simultaneousGesture` 기반 더블클릭 감지 (Table 행 선택과 충돌 없음)

### 내비게이션 (PanelState.swift)
- `navigate(to:)` — 히스토리에 추가하며 이동 (폴더 더블클릭용)
- `resetTo(_:)` — 히스토리 초기화 후 새 위치 이동 (사이드바 클릭용)
- `goBack()` / `goForward()` — history 스택 기반
- `refresh()` — 현재 폴더 목록 재로드

### 드래그 앤 드롭
- 패널 간 파일 드래그 이동 (`FileManager.moveItem`)
- 드롭 대상 패널에 초록 테두리 강조
- 같은 폴더 드롭 방지, 이름 충돌 시 "복사본" 접미사 자동 추가
- 드롭 완료 후 양쪽 패널 자동 새로고침

### 우클릭 컨텍스트 메뉴 (SinglePanelView.swift)
- 파일/폴더 위 우클릭: 열기, Finder에서 보기, 복사, 복제, 이름 변경, 휴지통으로 이동
- 빈 공간 우클릭: 새 폴더, 붙여넣기(클립보드에 파일 있을 때), 새로고침
- 다중 선택 시: N개 항목 열기, 복사, 휴지통으로 이동

### 키보드 단축키
- `Cmd+C` — 선택 파일 복사 (NSPasteboard)
- `Cmd+V` — 현재 폴더에 붙여넣기
- `Cmd+Delete` — 휴지통으로 이동
- 활성 패널에만 단축키 적용 (`.disabled(!isActive)`)

### 파일 작업 (AppViewModel.swift)
- `copyFiles`, `pasteFiles`, `duplicateFile`, `moveToTrash`, `revealInFinder`
- `showNewFolderDialog`, `showRenameDialog` — NSAlert + NSTextField 네이티브 다이얼로그
- `uniqueDestURL` — 이름 충돌 시 자동으로 고유 경로 생성

---

## 핵심 기술 결정 사항

| 결정 | 이유 |
|---|---|
| `HSplitView` 사용 | SwiftUI 기본 `HStack` 리사이즈 시 흔들림 → AppKit NSSplitView로 해결 |
| `simultaneousGesture` | Table 행 선택 제스처와 더블클릭 충돌 방지 |
| `resetTo` vs `navigate` | 사이드바 = 새 시작점, 폴더 더블클릭 = 히스토리 누적 |
| App Sandbox 비활성화 | 개인 도구, 파일 시스템 자유 접근 필요 |
| `Foundation.SortDescriptor` 미사용 | NSObject 요구로 Table sortOrder 바인딩 불가 → sortOrder 없는 Table 사용 |

---

## 알려진 이슈 / 미완료

- `FileRowView.swift` — 미사용 (그룹뷰는 SinglePanelView 내 인라인으로 구현됨, 추후 삭제 가능)
- `PanelView.swift` — 구버전 파일, 미사용 (추후 삭제 가능)
- `FileViewModel.swift` — 구버전 파일, 미사용 (추후 삭제 가능)

---

## Phase 2 진입 전 확인

- [x] 사이드바 → 활성 패널에 폴더 열기 동작
- [x] 패널 수 1/2/3/4 변경 동작
- [x] 폴더 더블클릭 → 이동 동작
- [x] 파일 더블클릭 → 기본 앱 실행 동작
- [x] 드래그 앤 드롭 이동 동작
- [x] 우클릭 컨텍스트 메뉴 동작
- [x] Cmd+C / Cmd+V / Cmd+Delete 동작
- [x] 빌드 성공
