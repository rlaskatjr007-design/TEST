import SwiftUI
import Combine

struct SidebarView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    private var homeURL: URL { URL(fileURLWithPath: NSHomeDirectory()) }
    private var desktopURL: URL { homeURL.appendingPathComponent("Desktop") }
    private var downloadsURL: URL { homeURL.appendingPathComponent("Downloads") }
    private var documentsURL: URL { homeURL.appendingPathComponent("Documents") }

    private var iCloudURL: URL? {
        let path = NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs"
        return FileManager.default.fileExists(atPath: path)
            ? URL(fileURLWithPath: path)
            : nil
    }

    var body: some View {
        List {
            Section("즐겨찾기") {
                SidebarRowButton(url: desktopURL,   label: "바탕화면", icon: "menubar.dock.rectangle")
                SidebarRowButton(url: downloadsURL, label: "다운로드",  icon: "arrow.down.circle")
                SidebarRowButton(url: documentsURL, label: "문서",      icon: "doc.text")
                SidebarRowButton(url: homeURL,      label: "홈 폴더",   icon: "house")
            }

            if let iCloud = iCloudURL {
                Section("iCloud Drive") {
                    SidebarRowButton(url: iCloud, label: "iCloud Drive", icon: "icloud")
                }
            }

            if !appViewModel.volumes.isEmpty {
                Section("외부 장치") {
                    ForEach(appViewModel.volumes, id: \.path) { volume in
                        SidebarRowButton(
                            url: volume,
                            label: volume.lastPathComponent,
                            icon: "externaldrive"
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                appViewModel.loadVolumes()
            } label: {
                Label("장치 새로고침", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 200)
    }
}

private struct SidebarRowButton: View {
    @EnvironmentObject var appViewModel: AppViewModel
    let url: URL
    let label: String
    let icon: String

    var body: some View {
        Button {
            appViewModel.openInActivePanel(url)
        } label: {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppViewModel())
        .frame(width: 220, height: 500)
}
