# 되돌리기 기능 + 네트워크 폴더 에러 처리 핸드오프

> 작성일: 2026년 4월 14일 | Phase 5 post6

---

## 작업 요약

1. **네트워크 공유 폴더 에러 처리** — SMB 마운트 폴더 접근 실패 시 빈 화면 대신 에러 메시지 표시
2. **되돌리기 기능** — 이미지 정리 / 이름 변경(바로 저장) 후 마지막 작업 1회 취소 가능

---

## 변경된 파일

| 파일 | 변경 내용 |
|---|---|
| `Models/PanelState.swift` | `loadError` 추가, `try?` → `do/catch` |
| `Views/SinglePanelView.swift` | `loadErrorView` 추가, panelContent에 에러 케이스 |
| `ViewModels/ImageOrganizerViewModel.swift` | `lastMoves`, `canUndo`, `undo()` 추가 |
| `ViewModels/FileRenamerViewModel.swift` | `lastRenames`, `canUndo`, `undo()` 추가 |
| `Views/ImageOrganizerView.swift` | 정리 완료 후 결과 카드(되돌리기 + 다시 정리) 표시 |
| `Views/FileRenamerView.swift` | 저장 버튼 왼쪽에 되돌리기 버튼 추가 |

---

## 1. 네트워크 폴더 에러 처리

### 문제
SMB 네트워크 공유 폴더를 사이드바에서 클릭하면 빈 화면만 표시됨.
`loadContents()`의 `try?`가 에러를 무시하고 `items = []` 상태로 return하기 때문.

### 해결
`PanelState`에 `@Published var loadError: String?` 추가.
`try?` → `do/catch`로 변경해 에러 메시지 캡처.

`SinglePanelView.panelContent`에 에러 케이스 추가:
```
currentURL == nil → emptyPlaceholder
loadError != nil  → loadErrorView (경고 아이콘 + 에러 메시지 + "다시 시도" 버튼)
items.isEmpty     → emptyFolder
groupByExtension  → extensionGroupedView
else              → tableView
```

---

## 2. 되돌리기 기능

### 설계 원칙
- **단일 레벨**: 마지막 작업 1회만 되돌리기 가능
- **바로 저장만 해당** (이름 변경): 별도 저장(복사본)은 원본 불변이므로 제외
- **이미지 정리**: 파일 원위치 복원 + 빈 날짜 폴더 삭제

### ImageOrganizerViewModel

```swift
@Published private(set) var lastMoves: [(from: URL, to: URL)] = []
var canUndo: Bool { !lastMoves.isEmpty }
```

- `organize()`: 각 파일 이동 성공 시 `(from: dest, to: originalFile)` 기록
- `undo()`:
  1. 파일 전부 원위치로 이동
  2. 빈 날짜 폴더 삭제
  3. 빈 `이미지/` 폴더 삭제 (옵션 A, 루트 폴더 제외)
- 폴더가 바뀌면 `lastMoves` 초기화 (`selectFolder`, `handleDrop`, `clearFolder`)

### FileRenamerViewModel

```swift
@Published private(set) var lastRenames: [(from: URL, to: URL)] = []
var canUndo: Bool { !lastRenames.isEmpty }
```

- `saveInPlace()`: 각 rename 성공 시 `(from: newURL, to: originalURL)` 기록
- `undo()`: 파일명 전부 원복 후 `loadFolder` 재호출

### UI 배치

**이미지 정리** — 정리 완료 후 "정리 시작" 버튼 영역이 결과 카드로 전환:
```
┌─────────────────────────────────┐
│ ✓ N개 파일 날짜별 정리 완료     │
│  [↩ 되돌리기]    [다시 정리]    │
└─────────────────────────────────┘
```
- `canUndo || !previewGroups.isEmpty` 조건으로 섹션 항상 유지
  (정리 후 previewGroups가 비어도 카드 표시)

**이름 변경** — 저장 버튼 왼쪽에 되돌리기 버튼:
```
[↩ 되돌리기]          [별도 저장] [바로 저장]
```

---

## 되돌리기 동작 규칙

| 상황 | 이미지 정리 | 이름 변경 |
|---|---|---|
| 작업 직후 | 활성화 ✓ | 활성화 ✓ |
| 같은 폴더 재로드 | 유지 ✓ | — |
| 다른 폴더 선택 | 초기화 ✗ | — |
| X 버튼 | 초기화 ✗ | — |
| 되돌리기 후 | 비활성화 ✗ | 비활성화 ✗ |
| 다시 정리/저장 시 | 새 기록으로 갱신 | 새 기록으로 갱신 |

---

## 빌드 상태

```
** BUILD SUCCEEDED **
```

Scheme: `Folder Flow`, Configuration: `Debug`
