# Phase 4 핸드오프 — 압축 파일 삭제

> 완료일: 2026년 3월 | 다음 단계: Phase 5

---

## 완료 내용

### 탭 추가 (ContentView.swift)
- `AppTab` enum에 `.archiveCleaner` 케이스 추가
- 탭 레이블: "압축 삭제" / 아이콘: `archivebox`

### 폴더 선택
- 뷰 전체 드롭존 (`.onDrop(of: [UTType.fileURL])`) + 파란 테두리 강조
- "폴더 선택" 버튼: NSOpenPanel
- X 버튼으로 초기화
- 새로고침(↺) 버튼: 재스캔

### 압축 파일 스캔
- 지원 확장자: `.zip .rar .7z .tar .gz`
- `.alz` 제외 (macOS 기본 지원 안 함)
- 최상위 파일만 스캔 (하위 폴더 재귀 없음)
- 비동기 스캔 (`DispatchQueue.global`)

### 파일 목록
- 확장자 컬러 배지: zip=파랑, rar=보라, 7z=주황, tar=갈색, gz=청록
- 파일명 / 크기 / 수정일 표시
- 체크박스 개별 선택/해제
- 행 클릭으로도 선택 토글
- 헤더 체크박스로 전체선택/해제
- 선택된 행 배경 연한 파란색 강조

### 우측 요약 패널
- 발견된 파일 수
- 선택된 파일 수
- 삭제 예정 용량 (선택 항목 합산)
- 확장자별 분류: 확장자명 / 개수 / 용량

### 삭제
- `NSWorkspace.shared.recycle()` — 즉시 삭제 아닌 휴지통 이동
- 선택 항목이 없으면 버튼 비활성화
- 삭제 완료 후 목록 자동 새로고침
- 완료 메시지 우측 패널 하단에 표시

---

## 핵심 기술 결정

| 결정 | 이유 |
|---|---|
| `NSWorkspace.shared.recycle()` | 즉시 삭제 대신 휴지통 이동 — 실수 복구 가능 |
| `loadObject(ofClass: NSURL.self)` | Phase 3에서 검증된 드롭 수신 방식 |
| 최상위 파일만 스캔 | 하위 폴더 재귀 스캔은 가이드 범위 이외 |
| 확장자 컬러 배지 | 파일 유형 빠른 구분 |

---

## 파일 구조 변경

```
추가된 파일:
├── ViewModels/ArchiveCleanerViewModel.swift
│     — ArchiveItem, ArchiveCleanerViewModel
│     — scan(), deleteSelected(), toggleSelectAll()
│     — selectedCount, selectedTotalSize, allSelected
└── Views/ArchiveCleanerView.swift
      — 좌측 파일 목록 + 체크박스, 우측 요약 패널

수정된 파일:
└── Views/ContentView.swift  — AppTab.archiveCleaner 추가
```

---

## 알려진 이슈 / 미완료
- 하위 폴더 재귀 스캔 없음 (최상위 파일만) — 가이드 범위 이내

---

## Phase 5 진입 전 확인

- [x] 폴더 드롭 / 폴더 선택 버튼 작동
- [x] 지원 확장자만 목록에 표시 (.alz 제외)
- [x] 체크박스 개별 선택/해제
- [x] 전체선택 / 전체해제 작동
- [x] 우측 요약: 발견 수 / 선택 수 / 삭제 예정 용량 표시
- [x] 확장자별 분류 표시
- [x] 삭제 시 휴지통으로 이동 (즉시 삭제 아님)
- [x] 삭제 후 목록 자동 새로고침
- [x] 빌드 성공 (에러 0개)
