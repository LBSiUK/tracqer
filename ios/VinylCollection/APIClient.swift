import Foundation
import UIKit

// MARK: - Errors

enum APIError: LocalizedError {
    case http(Int, String)
    case noData

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "Server error \(code): \(msg)"
        case .noData:                  return "No data received"
        }
    }
}

// MARK: - APIClient

final class APIClient: NSObject {

    let baseURL: String
    let key: Data
    let token: String

    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    init(baseURL: String, key: Data, token: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.key     = key
        self.token   = token
    }

    // MARK: - Core request

    func request<T: Decodable>(_ method: String, path: String, body: (any Encodable)? = nil) async throws -> T {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            let dict     = try body.toDictionary()
            let envelope = try CryptoService.encrypt(key: key, object: dict)
            req.httpBody = try JSONSerialization.data(withJSONObject: envelope)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return try await performAndDecrypt(req)
    }

    // No-body request returning nothing (DELETE → 204)
    func requestNoContent(_ method: String, path: String) async throws {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode < 300 else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 0, "")
        }
    }

    // Multipart upload for photos
    func uploadPhoto(path: String, imageData: Data, mimeType: String) async throws {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode < 300 else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 0, "Upload failed")
        }
    }

    // Multipart create-with-photos
    func createRecord(input: RecordInput, photos: [String: Data]) async throws -> VinylRecord {
        var req = URLRequest(url: URL(string: baseURL + "/api/v1/records/upload")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let dict     = try input.toDictionary()
        let envelope = try CryptoService.encrypt(key: key, object: dict)
        let metaJSON = try JSONSerialization.data(withJSONObject: envelope)

        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
        body.append(metaJSON)
        body.append("\r\n".data(using: .utf8)!)

        for (fieldName, imgData) in photos {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fieldName).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imgData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        return try await performAndDecrypt(req)
    }

    // MARK: - Photo URL

    func photoURL(recordId: String, photoType: String, discNumber: Int? = nil, size: String = "640") -> URL {
        let isDisc = photoType == "disc_front" || photoType == "disc_back"
        let path: String
        if isDisc, let disc = discNumber {
            path = "/api/v1/records/\(recordId)/photos/\(photoType)/\(disc)"
        } else {
            path = "/api/v1/records/\(recordId)/photos/\(photoType)"
        }
        return URL(string: "\(baseURL)\(path)?token=\(token)&size=\(size)")!
    }

    // MARK: - Image fetch (self-signed cert aware)

    func fetchImage(url: URL) async throws -> UIImage {
        let req = URLRequest(url: url)
        let (data, _) = try await session.data(for: req)
        guard let img = UIImage(data: data) else { throw APIError.noData }
        return img
    }

    // MARK: - Helpers

    private func performAndDecrypt<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, msg)
        }
        let envelope = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let decrypted = try CryptoService.decrypt(key: key, envelope: envelope)
        let plain = try JSONSerialization.data(withJSONObject: decrypted)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: plain)
    }
}

// MARK: - Self-signed certificate support

extension APIClient: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        // Accept any certificate — this app only talks to our home server
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

// MARK: - Encodable → Dictionary helper

extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}

// MARK: - Convenience record API methods

extension APIClient {

    func listRecords(search: String? = nil, page: Int = 1, limit: Int = 100) async throws -> RecordsResponse {
        var params: [String] = ["page=\(page)", "limit=\(limit)"]
        if let s = search, !s.isEmpty { params.append("search=\(s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)") }
        return try await request("GET", path: "/api/v1/records?\(params.joined(separator: "&"))")
    }

    func getRecord(_ id: String) async throws -> VinylRecord {
        try await request("GET", path: "/api/v1/records/\(id)")
    }

    func updateRecord(_ id: String, input: RecordInput) async throws -> VinylRecord {
        try await request("PATCH", path: "/api/v1/records/\(id)", body: input)
    }

    func deleteRecord(_ id: String) async throws {
        try await requestNoContent("DELETE", path: "/api/v1/records/\(id)")
    }

    func deletePhoto(recordId: String, photoType: String, discNumber: Int? = nil) async throws {
        let isDisc = photoType == "disc_front" || photoType == "disc_back"
        let path: String
        if isDisc, let disc = discNumber {
            path = "/api/v1/records/\(recordId)/photos/\(photoType)/\(disc)"
        } else {
            path = "/api/v1/records/\(recordId)/photos/\(photoType)"
        }
        try await requestNoContent("DELETE", path: path)
    }

    func uploadSleevePhoto(recordId: String, photoType: String, imageData: Data) async throws {
        try await uploadPhoto(path: "/api/v1/records/\(recordId)/photos/\(photoType)", imageData: imageData, mimeType: "image/jpeg")
    }

    func uploadDiscPhoto(recordId: String, photoType: String, discNumber: Int, imageData: Data) async throws {
        try await uploadPhoto(path: "/api/v1/records/\(recordId)/photos/\(photoType)/\(discNumber)", imageData: imageData, mimeType: "image/jpeg")
    }

    static func ping(baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/ping") else { return false }
        do {
            // Temporary session that also accepts self-signed certs
            let delegate = PingDelegate()
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let (_, resp) = try await session.data(from: url)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    static func verify(baseURL: String, key: Data, token: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/v1/auth/verify") else { return false }
        do {
            let envelope = try CryptoService.encrypt(key: key, object: [:])
            let body     = try JSONSerialization.data(withJSONObject: envelope)
            var req      = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody   = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let delegate = PingDelegate()
            let session  = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let (data, resp) = try await session.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
            let envResp = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let decrypted = try CryptoService.decrypt(key: key, envelope: envResp) as? [String: Any]
            return decrypted?["valid"] as? Bool == true
        } catch { return false }
    }
}

private final class PingDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
