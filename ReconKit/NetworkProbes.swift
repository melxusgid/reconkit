//
//  NetworkProbes.swift
//  ReconKit
//
//  Low-level TCP probes used by the scan engine: a raw TCP request/response
//  helper, a WHOIS client (port 43 with IANA referral), and a TCP port check.
//  All built on Network framework — sandbox-clean.
//

import Foundation
import Network
import Security

enum TCPProbe {
    /// Opens a TCP connection, optionally sends `payload`, then reads until the
    /// peer closes (or timeout). Returns the raw bytes received, or nil on
    /// failure. Used for line-oriented protocols like WHOIS.
    static func request(host: String, port: UInt16, payload: Data?, timeout: TimeInterval = 6.0) async -> Data? {
        let endpointPort = NWEndpoint.Port(rawValue: port) ?? .any
        let conn = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
        let queue = DispatchQueue(label: "reconkit.tcp")

        return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let guard_ = ProbeResumeGuard()
            let box = DataBox()

            func finish() {
                guard guard_.tryResume() else { return }
                conn.cancel()
                let data = box.value
                continuation.resume(returning: data.isEmpty ? nil : data)
            }

            queue.asyncAfter(deadline: .now() + timeout) { finish() }

            func readLoop() {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                    if let content { box.append(content) }
                    if isComplete || error != nil {
                        finish()
                    } else {
                        readLoop()
                    }
                }
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let payload {
                        conn.send(content: payload, completion: .contentProcessed { _ in readLoop() })
                    } else {
                        readLoop()
                    }
                case .failed, .cancelled:
                    finish()
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    /// True if a TCP handshake to host:port completes within the timeout.
    static func isOpen(host: String, port: UInt16, timeout: TimeInterval = 2.5) async -> Bool {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return false }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
        let queue = DispatchQueue(label: "reconkit.portcheck")

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let guard_ = ProbeResumeGuard()
            func finish(_ value: Bool) {
                guard guard_.tryResume() else { return }
                conn.cancel()
                continuation.resume(returning: value)
            }
            queue.asyncAfter(deadline: .now() + timeout) { finish(false) }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            conn.start(queue: queue)
        }
    }
}

enum TLSProbe {
    /// Opens a normal TLS connection to host:443 and reports the protocol
    /// version the server actually negotiates (e.g. "1.3"). This is accurate,
    /// unlike pinning min/max versions (which Network framework does not
    /// strictly enforce). Returns nil if the handshake fails.
    static func negotiatedVersion(host: String, timeout: TimeInterval = 6.0) async -> String? {
        let tls = NWProtocolTLS.Options()
        // We're inspecting config, not trusting the endpoint — accept any cert.
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in
            complete(true)
        }, DispatchQueue(label: "reconkit.tlsverify"))

        let conn = NWConnection(host: NWEndpoint.Host(host), port: 443, using: NWParameters(tls: tls))
        let queue = DispatchQueue(label: "reconkit.tlsprobe")

        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let guard_ = ProbeResumeGuard()
            func finish(_ value: String?) {
                guard guard_.tryResume() else { return }
                conn.cancel()
                continuation.resume(returning: value)
            }
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let meta = conn.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata
                    if let secMeta = meta?.securityProtocolMetadata {
                        let v = sec_protocol_metadata_get_negotiated_tls_protocol_version(secMeta)
                        finish(versionString(v))
                    } else {
                        finish(nil)
                    }
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    private static func versionString(_ v: tls_protocol_version_t) -> String? {
        switch v {
        case .TLSv13: return "1.3"
        case .TLSv12: return "1.2"
        case .TLSv11: return "1.1"
        case .TLSv10: return "1.0"
        default: return nil
        }
    }
}

enum BannerGrabber {
    /// Connects to host:port, reads whatever the service sends first (no
    /// request), and returns the first non-empty line. Works for protocols
    /// where the server greets first (SSH, SMTP, FTP, etc.).
    static func grab(host: String, port: UInt16, timeout: TimeInterval = 2.5) async -> String? {
        guard let data = await TCPProbe.request(host: host, port: port, payload: nil, timeout: timeout) else {
            return nil
        }
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(whereSeparator: \.isNewline) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return String(t.prefix(120)) }
        }
        return nil
    }
}

struct WHOISClient {
    /// Queries WHOIS for a domain, following IANA's referral to the registry
    /// server. Returns the registry response text, or the IANA text as fallback.
    func lookup(domain: String) async -> String? {
        let clean = domain.lowercased()
        // Ask IANA about the TLD to discover the registry's WHOIS server.
        let tld = clean.split(separator: ".").last.map(String.init) ?? clean
        guard let ianaRaw = await TCPProbe.request(
            host: "whois.iana.org", port: 43,
            payload: "\(tld)\r\n".data(using: .utf8)
        ) else { return nil }

        let ianaText = String(decoding: ianaRaw, as: UTF8.self)
        guard let refer = Self.referServer(in: ianaText) else { return ianaText }

        guard let registryRaw = await TCPProbe.request(
            host: refer, port: 43,
            payload: "\(clean)\r\n".data(using: .utf8)
        ) else { return ianaText }

        return String(decoding: registryRaw, as: UTF8.self)
    }

    /// Extracts the registry WHOIS server from an IANA response. TLD records
    /// use a `whois:` field; some responses use `refer:`.
    static func referServer(in text: String) -> String? {
        for prefix in ["refer:", "whois:"] {
            for line in text.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix(prefix) {
                    let server = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                    if !server.isEmpty { return server }
                }
            }
        }
        return nil
    }

    /// Pulls a value for the first matching key (case-insensitive) from WHOIS text.
    static func value(for keys: [String], in text: String) -> String? {
        let lowerKeys = keys.map { $0.lowercased() }
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            if lowerKeys.contains(key) {
                let v = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !v.isEmpty { return v }
            }
        }
        return nil
    }
}

/// Thread-safe byte accumulator for the read loop.
final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ chunk: Data) { lock.lock(); data.append(chunk); lock.unlock() }
    var value: Data { lock.lock(); defer { lock.unlock() }; return data }
}

/// One-shot resume guard for the TCP continuations.
final class ProbeResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func tryResume() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
