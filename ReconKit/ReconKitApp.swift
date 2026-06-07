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
            // MARK: File
            CommandGroup(after: .newItem) {
                Button("New Scan") {
                    coordinator.requestScanFocus = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Load Demo Scan") {
                    coordinator.loadSample()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()
            }

            // MARK: View
            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    // SwiftUI sidebar toggle — handled automatically
                    NSApp.keyWindow?.tryToggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }

            // MARK: Help
            CommandMenu("Help") {
                Link("Privacy Policy", destination: URL(string: "https://reconkit.fromthescope.com/privacy")!)
                    .keyboardShortcut("/", modifiers: [.command, .shift])
                Link("Terms of Use", destination: URL(string: "https://reconkit.fromthescope.com/terms")!)
                Link("ReconKit Website", destination: URL(string: "https://reconkit.fromthescope.com")!)
            }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
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
