# Phase 0 핸드오프 — 프로젝트 초기 세팅

> 완료일: 2026년 3월 | 다음 단계: Phase 1

---

## 완료 내용

### 프로젝트 기본 구조 세팅
- Xcode 26.3 프로젝트 생성 (objectVersion 77)
- 앱 이름: Folder Flow
- 언어: Swift 5.0 / SwiftUI
- 배포 타겟: macOS 13.0
- 라이트 모드 고정 (`.preferredColorScheme(.light)`)
- 창 최소 크기: 900×600 / 기본 크기: 1200×750

### 파일 구조 (소스 루트 기준)
```
Folder Flow/
├── App/
│   └── FolderFlowApp.swift       ← @main, AppViewModel 주입
├── Views/
│   ├── ContentView.swift
│   ├── SidebarView.swift
│   ├── PanelView.swift           (미사용 구버전)
│   ├── PanelGridView.swift
│   ├── SinglePanelView.swift
│   └── FileRowView.swift
├── Models/
│   └── FileItem.swift
└── ViewModels/
    ├── AppViewModel.swift
    └── FileViewModel.swift       (미사용)
```

### 핵심 빌드 설정
- `ENABLE_APP_SANDBOX = NO` (개인 도구 — App Store 배포 불가)
- `GENERATE_INFOPLIST_FILE = YES` (Info.plist 파일 없음)
- `PBXFileSystemSynchronizedRootGroup` 사용 — 파일 추가 시 `.pbxproj` 수동 등록 불필요

### Xcode 26 특이사항 (중요)
- `import Combine` 필수: SE-0403 기본 활성화로 `@Published`, `ObservableObject` 사용 시 반드시 명시
- Swift 6 실험 플래그 전부 제거됨 (재추가 시 `ObservableObject` 오류 발생)
- `@Observable`, `ContentUnavailableView` 사용 불가 (macOS 14+ 전용)

---

## 다음 Phase 진입 조건

- [x] Xcode 빌드 성공 (에러 0개)
- [x] 앱 실행 확인
- [x] 라이트 모드 고정 확인
- [x] App Sandbox 비활성화 확인
