# Quick Look (스페이스바 미리보기) 추가 핸드오프

> 작성일: 2026년 3월 31일 | Phase 5 post5 — macOS Quick Look 패널 연동

---

## 작업 요약

파일 선택 후 스페이스바를 누르면 macOS 네이티브 Quick Look 미리보기 패널이 열리는 기능을 추가했다.
Finder와 동일한 UX이며, 다중 선택 시 화살표로 파일 간 이동도 가능하다.

---

## 변경 사항

### 변경된 파일

**`Views/SinglePanelView.swift`** 만 변경

### 변경 내용

| 항목 | 내용 |
|---|---|
| `import Quartz` 추가 | QLPreviewPanel 사용을 위해 |
| `selectedURLs` 프로퍼티 추가 | 선택된 FileItem → URL 배열 변환 |
| `.background(QuickLookHelper(...))` 추가 | body VStack에 항상 존재 |
| `QuickLookHelper` 구조체 추가 | NSViewRepresentable — 키 모니터 + QL 패널 관리 |

---

## QuickLookHelper 구조

```
QuickLookHelper (NSViewRepresentable)
├── selectedURLs: [URL]   — 현재 선택된 파일 URL 목록
├── isActive: Bool        — 활성 패널 여부 (비활성 패널은 스페이스바 무반응)
├── updateNSView:
│   ├── coordinator.selectedURLs / isActive 갱신
│   ├── 패널이 이미 열려 있으면 reloadData() → 선택 변경 즉시 반영
│   └── keyDown NSEvent 모니터 설치 (1회)
├── dismantleNSView: 모니터 제거 + 패널 닫기
└── Coordinator (NSObject, QLPreviewPanelDataSource)
    ├── toggleQuickLook()
    │   ├── 패널 열려있음 → orderOut (닫기)
    │   └── 패널 닫혀있음 → dataSource = self → reloadData → makeKeyAndOrderFront
    ├── numberOfPreviewItems → selectedURLs.count
    └── previewItemAt → selectedURLs[index] as NSURL
```

---

## 동작 규칙

| 상황 | 동작 |
|---|---|
| 파일 1개 이상 선택 + 스페이스바 | Quick Look 패널 열림 |
| 패널 열린 상태에서 다른 파일 클릭 | 미리보기 자동 갱신 |
| 스페이스바 재입력 | 패널 닫힘 |
| 다중 선택 | QL 패널에서 ←→ 화살표로 파일 간 이동 |
| 비활성 패널에서 스페이스바 | 무반응 (이벤트 소비 안 함) |
| 아무것도 선택 안 한 상태 | 패널 열리지 않음 |

---

## 설계 결정

### QuickLookHelper를 별도 NSViewRepresentable로 분리한 이유

- `TableSetup`은 `tableView`의 `.background`에만 존재 → `extensionGroupedView` 표시 시 없어짐
- `QuickLookHelper`는 `SinglePanelView` body VStack `.background`에 추가 → 테이블/그룹뷰 모두 커버
- `TableSetup`에 합치면 그룹 뷰에서 스페이스바가 안 됨

### keyCode 49 (spacebar) 직접 감지

- SwiftUI `.keyboardShortcut(.space)` 는 macOS에서 신뢰성이 낮음
- NSEvent 모니터 방식은 post3/post4에서 검증된 패턴 — 동일하게 적용

### QLPreviewPanel 단일 인스턴스 관리

- `QLPreviewPanel.shared()` — 앱 전체 공유 인스턴스 (Finder와 동일)
- `dataSource = self` 를 직접 설정해 활성 패널의 Coordinator가 항상 데이터 공급
- 비활성 패널의 `QuickLookHelper`는 `isActive == false` → 스페이스바 이벤트 소비 안 함

---

## 주의사항

1. **SourceKit 오류**: `Cannot find type 'FileItem' in scope` 등 — 빌드 성공하므로 IDE 재인덱싱(Cmd+Shift+K 후 재빌드)으로 해결. post4 핸드오프와 동일한 증상.

2. **패널 소유권**: 다중 패널 환경에서 두 패널이 동시에 QL 패널을 열려 하면 마지막으로 스페이스바를 누른 패널이 `dataSource`를 가져감. 실사용에서 문제 없음.

3. **extensionGroupedView 호환**: 그룹 뷰에서도 파일을 클릭으로 선택한 뒤 스페이스바 → Quick Look 정상 동작.

---

## 빌드 상태

```
** BUILD SUCCEEDED **
```

Scheme: `Folder Flow`, Configuration: `Debug`
