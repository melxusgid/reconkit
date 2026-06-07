//
//  DNSClient.swift
//  ReconKit
//
//  Minimal DNS-over-UDP resolver built on Network framework. Sandbox-clean
//  (needs only com.apple.security.network.client). Supports the record types
//  useful for reconnaissance: A, AAAA, NS, CNAME, SOA, MX, TXT.
//

import Foundation
import Network

enum DNSType: UInt16 {
    case a = 1, ns = 2, cname = 5, soa = 6, ptr = 12, mx = 15, txt = 16, aaaa = 28
    case dnskey = 48, caa = 257

    var label: String {
        switch self {
        case .a: return "A"
        case .ns: return "NS"
        case .cname: return "CNAME"
        case .soa: return "SOA"
        case .ptr: return "PTR"
        case .mx: return "MX"
        case .txt: return "TXT"
        case .aaaa: return "AAAA"
        case .dnskey: return "DNSKEY"
        case .caa: return "CAA"
        }
    }
}

struct DNSRecord: Hashable {
    var type: DNSType
    var value: String
    var ttl: UInt32
}

/// Stateless resolver. Each `query` opens a short-lived UDP connection to a
/// public resolver, sends one question, and parses the first response.
struct DNSClient {
    var server: String = "1.1.1.1"
    var timeout: TimeInterval = 4.0

    func query(_ name: String, type: DNSType) async -> [DNSRecord] {
        guard let packet = Self.buildQuery(name: name, type: type) else { return [] }
        if let response = await sendUDP(packet) {
            let b = [UInt8](response)
            let truncated = b.count >= 3 && (b[2] & 0x02) != 0   // TC bit
            if !truncated { return Self.parseResponse(response, expected: type) }
        }
        // Truncated or no UDP answer — retry over TCP (RFC 7766).
        if let response = await sendTCP(packet) {
            return Self.parseResponse(response, expected: type)
        }
        return []
    }

    private func sendTCP(_ message: Data) async -> Data? {
        // DNS over TCP frames the message with a 2-byte big-endian length.
        var framed = Data()
        framed.append(UInt8(message.count >> 8))
        framed.append(UInt8(message.count & 0xFF))
        framed.append(message)
        guard let resp = await TCPProbe.request(host: server, port: 53, payload: framed, timeout: timeout + 2),
              resp.count > 2 else { return nil }
        return resp.subdata(in: 2..<resp.count)   // strip the length prefix
    }

    // MARK: - Networking

    private func sendUDP(_ data: Data) async -> Data? {
        let host = NWEndpoint.Host(server)
        let port = NWEndpoint.Port(rawValue: 53)!
        let conn = NWConnection(host: host, port: port, using: .udp)

        return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let resumed = ResumeGuard()
            let queue = DispatchQueue(label: "reconkit.dns")

            func finish(_ value: Data?) {
                guard resumed.tryResume() else { return }
                conn.cancel()
                continuation.resume(returning: value)
            }

            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.send(content: data, completion: .contentProcessed { error in
                        if error != nil { finish(nil); return }
                        conn.receiveMessage { content, _, _, _ in
                            finish(content)
                        }
                    })
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    // MARK: - Packet building

    static func buildQuery(name: String, type: DNSType) -> Data? {
        var packet = Data()
        // Header: fixed ID (0x4B49 "KI"), RD flag set, 1 question.
        packet.append(contentsOf: [0x4B, 0x49])       // ID
        packet.append(contentsOf: [0x01, 0x00])       // flags: RD
        packet.append(contentsOf: [0x00, 0x01])       // QDCOUNT
        packet.append(contentsOf: [0x00, 0x00])       // ANCOUNT
        packet.append(contentsOf: [0x00, 0x00])       // NSCOUNT
        packet.append(contentsOf: [0x00, 0x01])       // ARCOUNT (1 = EDNS0 OPT)

        // QNAME
        let host = name.hasSuffix(".") ? String(name.dropLast()) : name
        for label in host.split(separator: ".") {
            let bytes = Array(label.utf8)
            guard bytes.count < 64 else { return nil }
            packet.append(UInt8(bytes.count))
            packet.append(contentsOf: bytes)
        }
        packet.append(0x00)                            // root label

        // QTYPE + QCLASS (IN)
        packet.append(contentsOf: type.rawValue.bigEndianBytes)
        packet.append(contentsOf: [0x00, 0x01])

        // EDNS0 OPT record (additional section) advertising a 4096-byte UDP
        // buffer, so large answers (many TXT records, etc.) aren't truncated.
        packet.append(0x00)                 // root name
        packet.append(contentsOf: [0x00, 0x29])   // type OPT (41)
        packet.append(contentsOf: [0x10, 0x00])   // UDP payload size 4096
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // ext-rcode/version/flags
        packet.append(contentsOf: [0x00, 0x00])   // RDLEN 0
        return packet
    }

    // MARK: - Response parsing

    static func parseResponse(_ data: Data, expected: DNSType) -> [DNSRecord] {
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { return [] }

        let qd = Int(bytes[4]) << 8 | Int(bytes[5])
        let an = Int(bytes[6]) << 8 | Int(bytes[7])

        var offset = 12
        // Skip questions.
        for _ in 0..<qd {
            offset = skipName(bytes, offset)
            offset += 4 // QTYPE + QCLASS
            if offset > bytes.count { return [] }
        }

        var records: [DNSRecord] = []
        for _ in 0..<an {
            guard offset < bytes.count else { break }
            offset = skipName(bytes, offset)
            guard offset + 10 <= bytes.count else { break }
            let rtypeRaw = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
            let ttl = UInt32(bytes[offset + 4]) << 24 | UInt32(bytes[offset + 5]) << 16
                    | UInt32(bytes[offset + 6]) << 8 | UInt32(bytes[offset + 7])
            let rdlen = Int(bytes[offset + 8]) << 8 | Int(bytes[offset + 9])
            let rdStart = offset + 10
            guard rdStart + rdlen <= bytes.count else { break }

            if let rtype = DNSType(rawValue: rtypeRaw),
               let value = parseRData(bytes, type: rtype, start: rdStart, length: rdlen) {
                records.append(DNSRecord(type: rtype, value: value, ttl: ttl))
            }
            offset = rdStart + rdlen
        }
        return records
    }

    private static func parseRData(_ bytes: [UInt8], type: DNSType, start: Int, length: Int) -> String? {
        switch type {
        case .a:
            guard length == 4 else { return nil }
            return bytes[start..<start + 4].map(String.init).joined(separator: ".")
        case .aaaa:
            guard length == 16 else { return nil }
            var groups: [String] = []
            var i = start
            while i < start + 16 {
                let g = UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1])
                groups.append(String(g, radix: 16))
                i += 2
            }
            return groups.joined(separator: ":")
        case .ns, .cname, .ptr:
            return readName(bytes, start).name
        case .mx:
            guard length >= 3 else { return nil }
            let pref = Int(bytes[start]) << 8 | Int(bytes[start + 1])
            let host = readName(bytes, start + 2).name
            return "\(pref) \(host)"
        case .txt:
            var i = start
            var parts: [String] = []
            while i < start + length {
                let len = Int(bytes[i]); i += 1
                guard i + len <= start + length else { break }
                parts.append(String(decoding: bytes[i..<i + len], as: UTF8.self))
                i += len
            }
            return parts.joined()
        case .soa:
            let mname = readName(bytes, start)
            let rname = readName(bytes, mname.next)
            return "\(mname.name) \(rname.name)"
        case .dnskey:
            guard length >= 4 else { return nil }
            let proto = bytes[start + 2]
            let alg = bytes[start + 3]
            return "alg \(alg), proto \(proto)"
        case .caa:
            guard length >= 2 else { return nil }
            let tagLen = Int(bytes[start + 1])
            let tagStart = start + 2
            guard tagStart + tagLen <= start + length else { return nil }
            let tag = String(decoding: bytes[tagStart..<tagStart + tagLen], as: UTF8.self)
            let valStart = tagStart + tagLen
            let value = String(decoding: bytes[valStart..<start + length], as: UTF8.self)
            return "\(tag) \"\(value)\""
        }
    }

    // MARK: - Name parsing (handles compression pointers)

    /// Returns the offset immediately after the name at `offset`.
    private static func skipName(_ bytes: [UInt8], _ offset: Int) -> Int {
        var i = offset
        while i < bytes.count {
            let len = bytes[i]
            if len == 0 { return i + 1 }
            if len & 0xC0 == 0xC0 { return i + 2 } // pointer ends the name
            i += Int(len) + 1
        }
        return i
    }

    /// Reads a (possibly compressed) name. Returns the decoded name and the
    /// offset just past the name in the *original* stream.
    private static func readName(_ bytes: [UInt8], _ offset: Int) -> (name: String, next: Int) {
        var labels: [String] = []
        var i = offset
        var next: Int? = nil
        var hops = 0
        while i < bytes.count && hops < 128 {
            let len = bytes[i]
            if len == 0 { if next == nil { next = i + 1 }; break }
            if len & 0xC0 == 0xC0 {
                let ptr = (Int(len & 0x3F) << 8) | Int(bytes[i + 1])
                if next == nil { next = i + 2 }
                i = ptr
                hops += 1
                continue
            }
            let start = i + 1
            guard start + Int(len) <= bytes.count else { break }
            labels.append(String(decoding: bytes[start..<start + Int(len)], as: UTF8.self))
            i = start + Int(len)
        }
        return (labels.joined(separator: "."), next ?? i)
    }
}

/// One-shot resume guard so the continuation can't fire twice.
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func tryResume() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

private extension UInt16 {
    var bigEndianBytes: [UInt8] { [UInt8(self >> 8), UInt8(self & 0xFF)] }
}
