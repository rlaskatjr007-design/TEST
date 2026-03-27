import SwiftUI
import Combine

enum AppTab: CaseIterable {
    case fileExplorer, imageOrganizer, fileRenamer, archiveCleaner

    var label: String {
        switch self {
        case .fileExplorer:   return "파일 탐색기"
        case .imageOrganizer: return "이미지 정리"
        case .fileRenamer:    return "이름 변경"
        case .archiveCleaner: return "압축 삭제"
        }
    }

    var icon: String {
        switch self {
        case .fileExplorer:   return "folder"
        case .imageOrganizer: return "photo.stack"
        case .fileRenamer:    return "pencil.and.list.clipboard"
        case .archiveCleaner: return "archivebox"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var selectedTab: AppTab = .fileExplorer

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.label)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        selectedTab == tab
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                        }
                    }
                    .cornerRadius(4)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .fileExplorer:
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: 220)
                Divider()
                PanelGridView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .imageOrganizer:
            ImageOrganizerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .fileRenamer:
            FileRenamerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .archiveCleaner:
            ArchiveCleanerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
