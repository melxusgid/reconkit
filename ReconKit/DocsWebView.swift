//
//  DocsWebView.swift
//  ReconKit
//
//  Renders the live ReconKit documentation page in a WKWebView (the "ReconKit
//  Docs" window). In-page anchor links scroll within the view; any link that
//  leaves the docs page (Home, GitHub, Download, …) prompts the user to open it
//  in their default browser instead of navigating inside the app.
//

import SwiftUI
import WebKit

struct DocsWebView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        // Intercept clicked links that navigate away from the docs page.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = navigationAction.request.url else { decisionHandler(.allow); return }
            // Allow the initial load, reloads, form posts, etc. — only act on real clicks.
            guard navigationAction.navigationType == .linkActivated else { decisionHandler(.allow); return }

            let opensNewWindow = navigationAction.targetFrame == nil
            // In-page anchor (same scheme/host/path) → let it scroll inside the docs view.
            if !opensNewWindow, let current = webView.url, Coordinator.sameDocument(target, current) {
                decisionHandler(.allow)
                return
            }
            // Leaving the docs page → don't navigate in-app; offer the default browser.
            decisionHandler(.cancel)
            promptOpenInBrowser(target)
        }

        // target="_blank" / window.open links route here.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url { promptOpenInBrowser(url) }
            return nil
        }

        private static func sameDocument(_ a: URL, _ b: URL) -> Bool {
            a.scheme == b.scheme && a.host == b.host && a.path == b.path
        }

        private func promptOpenInBrowser(_ url: URL) {
            let alert = NSAlert()
            alert.messageText = "Open in your browser?"
            alert.informativeText = url.absoluteString
            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
