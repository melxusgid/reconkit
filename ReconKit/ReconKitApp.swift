//
//  ReconKitApp.swift
//  ReconKit
//
//  Created by RotaryPhone on 6/4/26.
//

import SwiftUI

@main
struct ReconKitApp: App {
    @StateObject private var coordinator = ScanCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 720)
        .commands {
            // MARK: File — New Scan replaces the default "New Window" (no \u2318N window conflict)
            CommandGroup(replacing: .newItem) {
                Button("New Scan") {
                    coordinator.requestScanFocus = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Load Demo Scan") {
                    coordinator.loadSample()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            // MARK: View
            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.tryToggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }

            // MARK: Help
            CommandMenu("Help") {
                OpenDocsButton()
                Divider()
                Link("Privacy Policy", destination: URL(string: "https://reconkit.fromthescope.com/privacy")!)
                Link("Terms of Use", destination: URL(string: "https://reconkit.fromthescope.com/terms")!)
                Link("ReconKit Website", destination: URL(string: "https://reconkit.fromthescope.com")!)
            }
        }

        // MARK: Docs window — loads the live documentation page
        Window("ReconKit Docs", id: "docs") {
            DocsWebView(url: URL(string: "https://reconkit.fromthescope.com/docs")!)
                .frame(minWidth: 720, minHeight: 600)
                .ignoresSafeArea()
        }
        .defaultSize(width: 920, height: 760)

        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
    }
}

/// Help-menu item that opens the in-app documentation window.
struct OpenDocsButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("ReconKit Docs") { openWindow(id: "docs") }
    }
}

/// Small AppKit helper to toggle the first responder's sidebar.
extension NSWindow {
    func tryToggleSidebar() {
        guard let splitView = contentView?.subviews.first(where: {
            String(describing: type(of: $0)).contains("SplitView")
        }) else { return }
        // Walk up to the NSSplitViewController and toggle.
        var responder: NSResponder? = splitView.nextResponder
        while responder != nil {
            if let splitVC = responder as? NSSplitViewController {
                splitVC.toggleSidebar(nil)
                return
            }
            responder = responder?.nextResponder
        }
    }
}
