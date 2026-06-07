//
//  ReportPDF.swift
//  ReconKit
//
//  Builds a professional, print-ready PDF report from a scan — the deliverable
//  a consultant hands to a client. Renders styled HTML through WebKit.
//

import AppKit
import WebKit
import UniformTypeIdentifiers

enum ReportPDF {

    // MARK: - Save flow

    @MainActor
    static func export(report: ScanReport) async {
        let html = html(for: report)
        guard let data = await renderPDF(html: html) else {
            NSSound.beep(); return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "ReconKit-\(report.target).pdf"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }

    // MARK: - Rendering

    @MainActor
    static func renderPDF(html: String) async -> Data? {
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 816, height: 1056)) // US Letter @96dpi
        let delegate = LoadWaiter()
        web.navigationDelegate = delegate
        web.loadHTMLString(html, baseURL: nil)
        await delegate.wait()
        // Give layout/fonts a beat to settle.
        try? await Task.sleep(nanoseconds: 250_000_000)
        let config = WKPDFConfiguration()
        return try? await web.pdf(configuration: config)
    }

    private final class LoadWaiter: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var finished = false
        func wait() async {
            await withCheckedContinuation { c in
                if finished { c.resume() } else { continuation = c }
            }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done() }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { done() }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { done() }
        private func done() {
            finished = true
            continuation?.resume()
            continuation = nil
        }
    }

    // MARK: - HTML

    static func html(for report: ScanReport) -> String {
        let df = DateFormatter()
        df.dateStyle = .long; df.timeStyle = .short
        let dateStr = df.string(from: report.date)

        let all = report.results.flatMap(\.findings)
        let issues = all.filter { $0.severity == .critical }.count
        let warns = all.filter { $0.severity == .warning }.count
        let passed = all.filter { $0.severity == .pass }.count

        let gradeColor = gradeHex(report.grade)

        var body = ""

        // Header
        body += """
        <div class="header">
          <div class="brand">
            <div class="logo">◎</div>
            <div><div class="bname">ReconKit</div><div class="bsub">Domain Security Report</div></div>
          </div>
          <div class="meta">\(escape(dateStr))</div>
        </div>
        <h1>\(escape(report.target))</h1>
        <div class="scorecard">
          <div class="grade" style="color:\(gradeColor);border-color:\(gradeColor)">\(report.grade)</div>
          <div class="scoreinfo">
            <div class="scorenum">\(report.score)<span>/100</span></div>
            <div class="rating">Security rating: <b>\(report.rating.label)</b></div>
          </div>
          <div class="tallies">
            <div class="tally"><span class="dot crit"></span>\(issues) Issues</div>
            <div class="tally"><span class="dot warn"></span>\(warns) Warnings</div>
            <div class="tally"><span class="dot pass"></span>\(passed) Passed</div>
          </div>
        </div>
        """

        // Action plan
        let plan = report.actionPlan
        if !plan.isEmpty {
            body += "<h2>Priority Action Plan</h2><div class=\"plan\">"
            for (i, item) in plan.enumerated() {
                let sevClass = item.finding.severity == .critical ? "crit" : "warn"
                body += """
                <div class="action">
                  <div class="anum \(sevClass)">\(i + 1)</div>
                  <div class="abody">
                    <div class="atitle">\(escape(item.finding.title)) <span class="tag \(sevClass)">\(item.category.rawValue)</span></div>
                    <div class="afix">\(escape(item.fix))</div>
                  </div>
                </div>
                """
            }
            body += "</div>"
        } else {
            body += "<h2>Priority Action Plan</h2><p class=\"clean\">No warnings or critical issues found. Nice work.</p>"
        }

        // Detailed findings by category
        body += "<h2>Detailed Findings</h2>"
        for result in report.results where result.category != .overview {
            body += "<h3>\(escape(result.category.rawValue)) <span class=\"summary\">\(escape(result.summary))</span></h3>"
            body += "<table>"
            for f in result.findings {
                let sevClass = sevClass(f.severity)
                body += """
                <tr>
                  <td class="sev"><span class="dot \(sevClass)"></span></td>
                  <td class="ftitle">\(escape(f.title))</td>
                  <td class="fdetail">\(escape(f.detail))</td>
                </tr>
                """
            }
            body += "</table>"
        }

        body += "<div class=\"footer\">Generated by ReconKit for macOS · Reconnaissance is read-only; no systems were accessed beyond public DNS, TLS, and HTTP queries.</div>"

        return shell(body: body)
    }

    // MARK: - Helpers

    private static func sevClass(_ s: Severity) -> String {
        switch s {
        case .critical: return "crit"
        case .warning: return "warn"
        case .pass: return "pass"
        case .info: return "info"
        }
    }

    private static func gradeHex(_ g: String) -> String {
        switch g {
        case "A": return "#00a36c"
        case "B": return "#6aa84f"
        case "C": return "#d6a400"
        case "D": return "#e8801a"
        default: return "#cf2d56"
        }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func shell(body: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8"><style>
        * { box-sizing: border-box; }
        body { font-family: -apple-system, "SF Pro Text", system-ui, sans-serif; color: #1a1d21;
               margin: 0; padding: 48px 44px; font-size: 12px; line-height: 1.5; }
        .header { display: flex; justify-content: space-between; align-items: center;
                  border-bottom: 2px solid #0053fd; padding-bottom: 14px; }
        .brand { display: flex; align-items: center; gap: 11px; }
        .logo { width: 34px; height: 34px; border-radius: 8px; background: #0053fd; color: #fff;
                font-size: 20px; text-align: center; line-height: 34px; }
        .bname { font-size: 17px; font-weight: 800; }
        .bsub { font-size: 10px; color: #6b7280; letter-spacing: .5px; text-transform: uppercase; }
        .meta { font-size: 11px; color: #6b7280; }
        h1 { font-size: 28px; margin: 26px 0 16px; }
        h2 { font-size: 15px; margin: 30px 0 12px; padding-bottom: 6px; border-bottom: 1px solid #e5e7eb; }
        h3 { font-size: 13px; margin: 18px 0 7px; }
        h3 .summary { font-weight: 400; color: #6b7280; font-family: ui-monospace, monospace; font-size: 11px; margin-left: 8px; }
        .scorecard { display: flex; align-items: center; gap: 26px; background: #f7f8fa;
                     border: 1px solid #e5e7eb; border-radius: 14px; padding: 20px 24px; }
        .grade { font-size: 40px; font-weight: 800; width: 70px; height: 70px; line-height: 66px;
                 text-align: center; border: 3px solid; border-radius: 50%; }
        .scorenum { font-size: 30px; font-weight: 800; font-family: ui-monospace, monospace; }
        .scorenum span { font-size: 14px; color: #9ca3af; }
        .rating { color: #4b5563; margin-top: 2px; }
        .tallies { margin-left: auto; }
        .tally { display: flex; align-items: center; gap: 7px; margin: 4px 0; font-weight: 600; }
        .dot { width: 9px; height: 9px; border-radius: 50%; display: inline-block; }
        .dot.crit { background: #cf2d56; } .dot.warn { background: #e8a317; }
        .dot.pass { background: #00a36c; } .dot.info { background: #0053fd; }
        .plan { display: flex; flex-direction: column; gap: 10px; }
        .action { display: flex; gap: 12px; background: #fbfbfc; border: 1px solid #e5e7eb;
                  border-radius: 10px; padding: 12px 14px; page-break-inside: avoid; }
        .anum { width: 24px; height: 24px; border-radius: 6px; color: #fff; font-weight: 700;
                text-align: center; line-height: 24px; flex-shrink: 0; }
        .anum.crit { background: #cf2d56; } .anum.warn { background: #e8a317; }
        .atitle { font-weight: 700; font-size: 12.5px; }
        .afix { color: #4b5563; margin-top: 3px; }
        .tag { font-size: 9px; font-weight: 700; padding: 1px 6px; border-radius: 4px; color: #fff;
               text-transform: uppercase; letter-spacing: .4px; vertical-align: middle; }
        .tag.crit { background: #cf2d56; } .tag.warn { background: #e8a317; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 6px; }
        td { padding: 6px 8px; border-bottom: 1px solid #eef0f2; vertical-align: top; }
        td.sev { width: 16px; } td.ftitle { width: 32%; font-weight: 600; }
        td.fdetail { color: #4b5563; font-family: ui-monospace, monospace; font-size: 10.5px; }
        .clean { color: #00a36c; font-weight: 600; }
        .footer { margin-top: 34px; padding-top: 12px; border-top: 1px solid #e5e7eb;
                  color: #9ca3af; font-size: 9.5px; }
        </style></head><body>\(body)</body></html>
        """
    }
}
