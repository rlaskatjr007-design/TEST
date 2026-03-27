# Phase 2 핸드오프 — 이미지 날짜별 자동 정리

> 완료일: 2026년 3월 | 다음 단계: Phase 3

---

## 완료 내용

### 탭 네비게이션 (ContentView.swift)
- 상단 탭 바 추가: **파일 탐색기** / **이미지 정리**
- `AppTab` enum (CaseIterable) — `.fileExplorer`, `.imageOrganizer`
- 파일 탐색기 탭: 기존 SidebarView + PanelGridView 그대로 유지
- 이미지 정리 탭: ImageOrganizerView 풀스크린

### 폴더 선택 (ImageOrganizerView.swift)
- 드롭존: 폴더 드래그&드롭 (`.onDrop(of: [UTType.fileURL])`) — 뷰 전체에 적용
- "폴더 선택" 버튼: NSOpenPanel (canChooseDirectories = true)
- 선택된 폴더 표시 + X 버튼으로 초기화
- `isDropTargeted` → 드롭 시 전체 뷰에 파란 테두리 강조

### 정리 방식 선택
- **옵션 A**: `선택폴더/이미지/2026-03-25/` (이미지 폴더 하위)
- **옵션 B**: `선택폴더/2026-03-25/` (날짜 폴더 바로 생성)
- 옵션 변경 시 미리보기 자동 갱신

### 미리보기 트리 (오른쪽 패널)
- 날짜 내림차순 정렬
- 각 날짜 그룹: 폴더 아이콘 + 날짜 + 배지 + 파일 수
  - **새 폴더** (초록 배지): 해당 날짜 폴더가 아직 없음
  - **기존 폴더에 추가** (주황 배지): 이미 존재하는 폴더에 병합 예정
- 그룹 클릭으로 파일 목록 접기/펼치기
- 새로고침 버튼 (↺)

### 정리 실행 (ImageOrganizerViewModel.swift)
- 대상: `.jpg .jpeg .png .gif .heic .webp` 6가지 확장자만
- 날짜 기준: **파일 생성일** (creationDate) 사용
- 날짜 폴더 중복 시 기존 폴더에 파일만 추가 (폴더 새로 만들지 않음)
- 이미지 폴더(옵션 A) 중복 시에도 기존 폴더 사용
- 파일명 충돌 시 `파일명 2.jpg`, `파일명 3.jpg` 자동 넘버링
- DispatchQueue.global 비동기 처리
- 완료 후 completionMessage + 미리보기 자동 새로고침

---

## 핵심 기술 결정 사항

| 결정 | 이유 |
|---|---|
| `UTType.fileURL` (UniformTypeIdentifiers) | macOS 11+ 지원, 타입 안전한 드롭 처리 |
| 생성일(creationDate) 기준 날짜 분류 | 가이드 명시 요건 |
| `.onDrop` 뷰 전체 적용 | 드롭존 영역 제한 없이 어디든 드롭 가능하도록 |
| 비동기 파일 이동 (global queue) | 대량 파일 처리 시 UI 블로킹 방지 |

---

## 파일 구조 변경

```
추가된 파일:
├── ViewModels/ImageOrganizerViewModel.swift  — OrganizeOption, PreviewGroup, ImageOrganizerViewModel
└── Views/ImageOrganizerView.swift            — ImageOrganizerView, PreviewGroupRow

수정된 파일:
└── Views/ContentView.swift                  — AppTab enum + 탭 바 추가
```

---

## 알려진 이슈 / 미완료

- 하위 폴더 재귀 스캔 없음 (최상위 파일만) — 가이드 범위 이내
- 이미지 썸네일 미리보기 없음 — Phase 5 UI 통합 시 추가 가능

---

## Phase 3 진입 전 확인

- [x] 탭 바로 파일 탐색기 ↔ 이미지 정리 전환 가능
- [x] 폴더 드래그&드롭으로 선택 가능
- [x] "폴더 선택" 버튼으로 선택 가능
- [x] 옵션 A / B 선택 UI 작동
- [x] 미리보기 트리에 날짜 그룹 표시
- [x] 새 폴더 / 기존 폴더에 추가 배지 구분
- [x] 정리 시작 후 실제 날짜 폴더 생성 및 파일 이동
- [x] 날짜 폴더 중복 생성 안 됨
- [x] 완료 메시지 표시
- [x] 빌드 성공 (에러 0개)
