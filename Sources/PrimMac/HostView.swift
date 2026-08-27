import AppKit
import PrimMacCore
import PrimSimCore
import SwiftUI

struct HostView: View {
    @EnvironmentObject private var desk: DeskModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WorkRail()
        } detail: {
            StageView()
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: desk.showSettings) {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .disabled(desk.askFDA)
            }
        }
        .onAppear {
            columnVisibility = desk.railHidden ? .detailOnly : .all
            desk.boot()
        }
        .onChange(of: desk.railHidden) { hidden in
            let next: NavigationSplitViewVisibility = hidden ? .detailOnly : .all
            if columnVisibility != next { columnVisibility = next }
        }
        .onChange(of: columnVisibility) { vis in
            let hidden = vis == .detailOnly
            if desk.railHidden != hidden { desk.railHidden = hidden }
        }
        .sheet(isPresented: $desk.askFDA) {
            FDARequestSheet(onGrant: desk.grantFDA, onLater: { desk.askFDA = false })
        }
    }
}

struct FDARequestSheet: View {
    var onGrant: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allow access to Messages?")
                .font(.title2)
            Text("Prims Desktop needs Full Disk Access to read chat.db. macOS will not show its own prompt. We’ll open Settings so you can turn on Prims Desktop, then quit and reopen this app.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Not now") { onLater() }
                Spacer()
                Button("Open Settings") { onGrant() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
