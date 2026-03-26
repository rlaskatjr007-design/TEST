# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Xcode 26 프로젝트. CLI 빌드:

```bash
# Xcode developer directory 설정 (최초 1회)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 빌드
cd "/Users/rev_imac2/Documents/Folder Flow/Folder Flow"
xcodebuild -project "Folder Flow.xcodeproj" -scheme "Folder Flow" -configuration Debug build
```

Xcode에서: **Cmd+B** 빌드 / **Shift+Cmd+K** Clean Build Folder

## 프로젝트 구조

```
Folder Flow/                          ← Xcode 프로젝트 루트
├── Folder Flow.xcodeproj/
│   └── project.pbxproj               ← 빌드 설정 (배포 타겟, 권한, Swift 설정)
└── Folder Flow/                      ← 소스 루트 (PBXFileSystemSynchronizedRootGroup)
    ├── App/FolderFlowApp.swift        ← @main 진입점, 창 크기/라이트모드 설정
    ├── Views/
    │   ├── ContentView.swift          ← NavigationSplitView 루트
    │   ├── SidebarView.swift          ← 파일 목록 + 폴더 열기 버튼
    │   └── PanelView.swift            ← 선택 파일 상세
    ├── Models/FileItem.swift          ← Identifiable, Hashable 파일 모델
    └── ViewModels/FileViewModel.swift ← ObservableObject, NSOpenPanel 파일 접근
```

**PBXFileSystemSynchronizedRootGroup**: `Folder Flow/` 하위 파일/폴더를 Xcode가 자동 인식. `.pbxproj`에 수동으로 파일 등록 불필요.

## 핵심 설정 (project.pbxproj)

- **배포 타겟**: macOS 13.0
- **Swift 버전**: 5.0
- **샌드박스**: `ENABLE_APP_SANDBOX = YES`, `ENABLE_USER_SELECTED_FILES = readwrite`
- **Info.plist 자동 생성**: `GENERATE_INFOPLIST_FILE = YES` — Info.plist 파일 없음, 키는 `INFOPLIST_KEY_*` 빌드 설정으로 관리

## Xcode 26 주의사항

이 프로젝트는 **Xcode 26** (objectVersion 77, CreatedOnToolsVersion 26.3)으로 생성됨.

- **`import Combine` 필수**: Xcode 26은 SE-0403 MemberImportVisibility를 기본 활성화. `@Published`, `ObservableObject`는 `import SwiftUI`만으로 해결되지 않으며, `import Combine`을 명시해야 함
- **Swift 6 실험 플래그 제거됨**: `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_DEFAULT_ACTOR_ISOLATION`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` 모두 제거 — 재추가 시 `ObservableObject` 적합성 오류 발생
- **macOS 13 타겟**: `ContentUnavailableView`(14.0+), `@Observable`(14.0+) 사용 불가

## 권한 모델

파일 접근은 **NSOpenPanel** 방식만 사용. 직접 경로 접근 불가(샌드박스).
`FileViewModel.openFolder()` → `NSOpenPanel.runModal()` → `FileManager.contentsOfDirectory`.

## 라이트 모드 고정

`FolderFlowApp.swift`의 `.preferredColorScheme(.light)`으로 코드 레벨에서 강제. Info.plist `NSRequiresAquaSystemAppearance` 미사용.
