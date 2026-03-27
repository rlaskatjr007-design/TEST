# Phase 5 핸드오프 — UI 통합 및 마무리

> 완료일: 2026년 3월 27일 | 상태: Folder Flow v1.0 완성

---

## 변경 내용

### FolderFlowApp.swift
- `WindowGroup("Folder Flow")` — 타이틀바에 앱 이름 명시

### ContentView.swift
- 탭바 우측에 앱 브랜딩 추가
  - SF Symbol: `folder.badge.gearshape` + "Folder Flow" 텍스트
  - `tertiaryLabelColor`로 조용하게 표시

---

## Phase 5 점검 항목

- [x] 3개 기능이 탭으로 전환 가능 (파일 탐색기 / 이미지 정리 / 이름 변경)
- [x] 각 기능이 전환 후에도 정상 작동
- [x] 3개 탭 모두 좌/우 2단 구조 통일됨
- [x] 전체 accentColor 기반 스타일 통일
- [x] 라이트 모드 고정 (preferredColorScheme(.light))
- [x] 타이틀바에 "Folder Flow" 표시됨 (WindowGroup 제목)
- [x] 창 최소 크기 900x600 유지 (frame minWidth/minHeight)
- [ ] 최종 빌드 성공 확인 (Xcode에서 직접 확인 필요)

---

## 미사용 파일 (Xcode에서 직접 삭제 권장)

| 파일 | 상태 |
|---|---|
| `ViewModels/FileViewModel.swift` | PanelView에서만 참조, PanelView 미사용 |
| `Views/FileRowView.swift` | 어디서도 사용 안 됨 |
| `Views/PanelView.swift` | 구버전, 어디서도 사용 안 됨 |

> Xcode에서 파일 선택 → Delete → "Move to Trash" 선택

---

## 최종 탭 구성

| 탭 | 파일 | 구조 |
|---|---|---|
| 📂 파일 탐색기 | SidebarView + PanelGridView | 좌(사이드바220) + 우(패널) |
| 🖼 이미지 정리 | ImageOrganizerView | 좌(설정300) + 우(미리보기) |
| ✏️ 이름 변경 | FileRenamerView | 좌(파일목록320~400) + 우(작업패널) |

---

## 핵심 기술 제약 (유지)

- macOS 13.0 deployment target
- Xcode 26, Swift 5.0
- `import Combine` 필수
- App Sandbox 비활성화
