//
//  HTTPProbe.swift
//  ReconKit
//
//  Fetches a URL over HTTPS, capturing status, headers, the redirect chain,
//  and the TLS leaf certificate details (issuer, validity window). Built on
//  URLSession — sandbox-clean with com.apple.security.network.client.
//

import Foundation
import Security

struct TLSCertInfo {
    var commonName: String?
    var issuer: String?
    var notBefore: Date?
    var notAfter: Date?
    var sans: [String] = []
    var chainLength: Int = 0

    var daysUntilExpiry: Int? {
        guard let notAfter else { return nil }
        let secs = notAfter.timeIntervalSinceNow
        return Int(secs / 86400)
    }
}

struct HTTPResult {
    var finalURL: URL
    var statusCode: Int
    var headers: [String: String]
    var redirectChain: [String]
    var cert: TLSCertInfo?
    var serverHeader: String?
}

/// Performs one HTTPS request and reports the response metadata. Reuses a
/// single delegate instance to capture redirects and the server trust.
final class HTTPProbe: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private var redirectChain: [String] = []
    private var capturedCert: TLSCertInfo?

    func fetch(urlString: String, timeout: TimeInterval = 12.0) async -> HTTPResult? {
        guard let url = normalizedURL(from: urlString) else { return nil }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("ReconKit/1.0 (macOS security scanner)", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            var headers: [String: String] = [:]
            for (k, v) in http.allHeaderFields {
                headers[String(describing: k)] = String(describing: v)
            }
            return HTTPResult(
                finalURL: http.url ?? url,
                statusCode: http.statusCode,
                headers: headers,
                redirectChain: redirectChain,
                cert: capturedCert,
                serverHeader: headers.first { $0.key.lowercased() == "server" }?.value
            )
        } catch {
            return nil
        }
    }

    private func normalizedURL(from raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        return URL(string: s)
    }

    // Record redirects for the HTTP tab.
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let from = response.url?.absoluteString { redirectChain.append(from) }
        completionHandler(request)
    }

    // Capture the leaf certificate from the server trust, then continue
    // the default evaluation.
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            if capturedCert == nil { capturedCert = Self.leafInfo(from: trust) }
        }
        completionHandler(.performDefaultHandling, nil)
    }

    static func leafInfo(from trust: SecTrust) -> TLSCertInfo? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else { return nil }

        var info = TLSCertInfo()
        info.chainLength = chain.count
        info.commonName = {
            var cn: CFString?
            SecCertificateCopyCommonName(leaf, &cn)
            return cn as String?
        }()

        let keys = [
            kSecOIDX509V1ValidityNotBefore,
            kSecOIDX509V1ValidityNotAfter,
            kSecOIDX509V1IssuerName,
            kSecOIDSubjectAltName,
        ] as CFArray
        guard let values = SecCertificateCopyValues(leaf, keys, nil) as? [CFString: Any] else {
            return info
        }

        func date(for oid: CFString) -> Date? {
            guard let entry = values[oid] as? [CFString: Any],
                  let num = entry[kSecPropertyKeyValue] as? NSNumber else { return nil }
            // Value is seconds since the reference date (2001-01-01).
            return Date(timeIntervalSinceReferenceDate: num.doubleValue)
        }
        info.notBefore = date(for: kSecOIDX509V1ValidityNotBefore)
        info.notAfter = date(for: kSecOIDX509V1ValidityNotAfter)

        // Issuer organization, best-effort, from the issuer name section.
        if let issuerEntry = values[kSecOIDX509V1IssuerName] as? [CFString: Any],
           let parts = issuerEntry[kSecPropertyKeyValue] as? [[CFString: Any]] {
            for part in parts {
                if let label = part[kSecPropertyKeyLabel] as? String,
                   label == "2.5.4.10" || label.lowercased() == "organizationname" || label == "O",
                   let value = part[kSecPropertyKeyValue] as? String {
                    info.issuer = value
                    break
                }
            }
            if info.issuer == nil {
                // Fall back to the common-name component of the issuer.
                for part in parts {
                    if let label = part[kSecPropertyKeyLabel] as? String,
                       label == "2.5.4.3",
                       let value = part[kSecPropertyKeyValue] as? String {
                        info.issuer = value
                        break
                    }
                }
            }
        }

        // Subject Alternative Names (the hostnames the cert is valid for).
        if let sanEntry = values[kSecOIDSubjectAltName] as? [CFString: Any],
           let parts = sanEntry[kSecPropertyKeyValue] as? [[CFString: Any]] {
            var names: [String] = []
            for part in parts {
                let label = (part[kSecPropertyKeyLabel] as? String)?.lowercased() ?? ""
                if label.contains("dns"), let value = part[kSecPropertyKeyValue] as? String {
                    names.append(value)
                }
            }
            info.sans = names
        }
        return info
    }
}
