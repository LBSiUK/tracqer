import SwiftUI
import Observation

private let kServerURL = "vinyl_server_url"
private let kKeyData   = "vinyl_key_data"
private let kToken     = "vinyl_token"

@MainActor
@Observable
final class AppState {

    var api: APIClient? = nil
    var records: [VinylRecord] = []
    var searchResults: [VinylRecord] = []
    var isLoading = false
    var errorMessage: String? = nil

    // Restore session on launch
    init() {
        if let url    = UserDefaults.standard.string(forKey: kServerURL),
           let keyB64 = UserDefaults.standard.string(forKey: kKeyData),
           let key    = Data(base64Encoded: keyB64),
           let token  = UserDefaults.standard.string(forKey: kToken) {
            api = APIClient(baseURL: url, key: key, token: token)
        }
    }

    func login(serverURL: String, password: String) async throws {
        let url = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL

        guard await APIClient.ping(baseURL: url) else {
            throw LoginError.unreachable
        }

        let key   = try CryptoService.deriveKey(from: password)
        let token = CryptoService.keyToToken(key)

        guard await APIClient.verify(baseURL: url, key: key, token: token) else {
            throw LoginError.wrongPassword
        }

        let client = APIClient(baseURL: url, key: key, token: token)
        api = client

        UserDefaults.standard.set(url,                       forKey: kServerURL)
        UserDefaults.standard.set(key.base64EncodedString(), forKey: kKeyData)
        UserDefaults.standard.set(token,                     forKey: kToken)
    }

    func logout() {
        api = nil
        records = []
        searchResults = []
        UserDefaults.standard.removeObject(forKey: kServerURL)
        UserDefaults.standard.removeObject(forKey: kKeyData)
        UserDefaults.standard.removeObject(forKey: kToken)
    }

    func loadRecords(search: String? = nil) async {
        guard let api else { return }
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await api.listRecords(search: search, limit: 200)
            records = resp.records
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func performSearch(query: String) async {
        guard let api, !query.isEmpty else { searchResults = []; return }
        do {
            let resp = try await api.listRecords(search: query, limit: 100)
            searchResults = resp.records
        } catch {
            searchResults = []
        }
    }

    func deleteRecord(_ id: String) async throws {
        guard let api else { return }
        try await api.deleteRecord(id)
        records.removeAll { $0.id == id }
        searchResults.removeAll { $0.id == id }
    }
}

enum LoginError: LocalizedError {
    case unreachable
    case wrongPassword

    var errorDescription: String? {
        switch self {
        case .unreachable:   return "Cannot reach server. Check the URL."
        case .wrongPassword: return "Wrong password."
        }
    }
}
