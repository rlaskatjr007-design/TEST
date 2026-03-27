import SwiftUI
import Combine

struct PanelGridView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            panelCountBar
            Divider()

            // HSplitView uses AppKit NSSplitView — smooth native resize, no jitter
            HSplitView {
                ForEach(appViewModel.panels) { panel in
                    SinglePanelView(panel: panel)
                        .frame(minWidth: 180)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var panelCountBar: some View {
        HStack(spacing: 6) {
            Text("패널")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach([1, 2], id: \.self) { count in
                Button {
                    appViewModel.setPanelCount(count)
                } label: {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(width: 24, height: 24)
                        .background(
                            appViewModel.panelCount == count
                                ? Color.accentColor
                                : Color(NSColor.controlBackgroundColor)
                        )
                        .foregroundColor(appViewModel.panelCount == count ? .white : .primary)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    PanelGridView()
        .environmentObject(AppViewModel())
        .frame(width: 800, height: 600)
}
