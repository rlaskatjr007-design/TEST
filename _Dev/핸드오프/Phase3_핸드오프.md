# Phase 3 핸드오프 — 파일 이름 일괄 변경

> 완료일: 2026년 3월 | 다음 단계: Phase 4

---

## 완료 내용

### 탭 추가 (ContentView.swift)
- `AppTab` enum에 `.fileRenamer` 케이스 추가
- 탭 레이블: "이름 변경" / 아이콘: `pencil.and.list.clipboard`

### 폴더 선택
- 뷰 전체 드롭존 (`.onDrop(of: [UTType.fileURL])`) + 파란 테두리 강조
- "폴더 선택" 버튼: NSOpenPanel
- X 버튼으로 초기화

### 모드 A — 일괄 넘버링
- 기본 이름 TextField
- **번호 설정 한 줄 compact 레이아웃**: 시작 번호 Stepper | [앞][뒤] 위치 선택 | [1][01][001] 자릿수 선택
- 미리보기가 나머지 공간 전체를 채움 (항상 표시, 입력 전엔 안내 문구)
- 미리보기에 원본 → 변경명 나란히 표시
- **파일 선택 체크박스**: 전체선택/해제 + 개별 체크박스, 선택된 파일만 넘버링 대상
- 선택 해제된 파일은 흐리게 표시

### 모드 B — 개별 이름 변경
- **2컬럼 테이블 구조**: 원본 파일명 | → | 새 이름 입력 (가로 공간 전체 활용)
- 확장자 자동 유지 (입력 불필요)
- 중복 파일명 감지: **확장자까지 포함한 최종 파일명 기준** 비교
  - `사진.jpg` vs `사진.png` → 확장자 다르면 중복 아님
- **포커스 아웃 시에만 중복 표시** (타이핑 중에는 표시 안 함)
  - `@FocusState`로 편집 중인 항목 추적, 포커스 벗어날 때 비교 실행
- 중복 시: 빨간 배경 + 경고 아이콘 (좌측 파일 목록 + 우측 입력 필드 양쪽)
- 저장 시 중복 있으면 팝업 차단 + 중복 파일명 목록 표시

### 저장 방식 (두 모드 공통)
- **바로 저장**: FileManager.moveItem — 원본 이름 즉시 변경, 완료 후 목록 갱신
- **별도 저장**: NSOpenPanel 경로 선택 후 FileManager.copyItem
- 파일명 충돌 시 자동 넘버링 (`파일명 2.ext`)

### Cmd+F 검색
- `Cmd+F` 토글로 검색 바 표시/숨김
- 원본 파일명 기준 실시간 필터링 (두 모드 공통)
- X 버튼 또는 재입력으로 초기화

---

## 핵심 기술 결정

| 결정 | 이유 |
|---|---|
| `selectedIndex` 내부 계산 (선택 항목 기준) | 체크박스로 일부만 선택해도 번호가 001부터 순차 |
| 확장자 포함 중복 비교 | `사진.jpg` ≠ `사진.png` — 실제 파일명은 다름 |
| `@FocusState`로 중복 감지 타이밍 제어 | 타이핑 중 불필요한 경고 방지 |
| `ForEach(vm.items.indices)` + 수동 Binding | `ForEach($vm.items)` 안에 `if` 쓰면 타입 추론 오류 발생 |
| `loadObject(ofClass: NSURL.self)` | `loadItem(forTypeIdentifier:)` 는 파일 고유 UTType 등록 시 실패 |

---

## 파일 탐색기 보완 (Phase 3 세션 중 수정)

### 드래그 멀티 파일 이동 (AppViewModel.swift, SinglePanelView.swift)
- 다중 선택 후 드래그 시 선택된 파일 전체 이동
- `pendingDragURLs`에 선택된 URL 전체 저장, 드롭 시 한꺼번에 처리
- 외부(Finder) 드래그는 단일 파일로 정상 처리

### 드롭 수신 방식 수정 (SinglePanelView.swift)
- 기존 `loadItem(forTypeIdentifier: "public.file-url")` → `loadObject(ofClass: NSURL.self)` 로 변경
- 파일 고유 UTType(예: `public.jpeg`)으로 등록된 경우도 정상 수신

### 클릭 감지 개선 (SinglePanelView.swift)
- 헤더, 경로 바, 빈 상태 뷰 각각에 `.onTapGesture` 명시적 추가
- 클릭 시 헤더에 파란 플래시 효과 (0.3초) — 활성화 시각 확인

## 이미지 정리 보완 (Phase 3 세션 중 수정)

### 날짜 기준 변경 (ImageOrganizerViewModel.swift)
- 기존: EXIF → 생성일 → 수정일 순서
- 변경: **수정일(contentModificationDate) 단일 기준**

---

## 파일 구조 변경

```
추가된 파일:
├── ViewModels/FileRenamerViewModel.swift
│     — RenameMode, NumberPosition, NumberPadding, RenameItem, FileRenamerViewModel
└── Views/FileRenamerView.swift
      — 좌/우 2단 레이아웃, 모드 A/B, 검색, 저장

수정된 파일:
├── Views/ContentView.swift              — AppTab.fileRenamer 추가
├── ViewModels/AppViewModel.swift        — pendingDragURLs, startDrag 멀티 선택 지원
├── Views/SinglePanelView.swift          — loadObject, 클릭 개선, activate()
└── ViewModels/ImageOrganizerViewModel.swift — 수정일 기준 날짜 분류
```

---

## 알려진 이슈 / 미완료
- 하위 폴더 재귀 스캔 없음 (최상위 파일만) — 가이드 범위 이내

---

## Phase 4 진입 전 확인

- [x] 폴더 드롭 / 폴더 선택 버튼 작동
- [x] 모드 A: 기본 이름 + 번호 위치(앞/뒤) + 자릿수(1/01/001) 선택
- [x] 모드 A: 파일 체크박스 선택, 전체선택/해제
- [x] 모드 A: 선택된 파일만 넘버링, 미리보기 실시간 반영
- [x] 모드 B: 2컬럼 테이블 레이아웃
- [x] 모드 B: 중복 감지 (확장자 포함), 포커스 아웃 시 표시
- [x] 모드 B: 저장 시 중복 차단 팝업
- [x] Cmd+F 검색 작동
- [x] 바로 저장 / 별도 저장 작동
- [x] 확장자 자동 유지
- [x] 파일 탐색기: 다중 선택 드래그 이동
- [x] 파일 탐색기: 클릭 감지 + 플래시 피드백
- [x] 이미지 정리: 수정일 기준 날짜 분류
- [x] 빌드 성공 (에러 0개)
