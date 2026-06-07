//
//  DocsWebView.swift
//  ReconKit
//
//  Renders the live ReconKit documentation page in a WKWebView, shown in
//  the dedicated "ReconKit Docs" window.
//

import SwiftUI
import WebKit

struct DocsWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
