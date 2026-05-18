import Foundation

// MARK: - Domain types

typealias Grade  = String
typealias Format = String
typealias Speed  = String
typealias Owner  = String

struct Photo: Codable, Identifiable, Hashable {
    let id: String
    let photo_type: String
    let disc_number: Int?
    let mime_type: String
    let file_size: Int
    var url: String
    let created_at: String
}

struct VinylRecord: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var artist: String
    var year: Int?
    var duration: String?
    var label: String?
    var format: String?
    var speed: String?
    var genre: String?
    var notes: String?
    var owner: String
    var disc_count: Int
    var outer_sleeve_only: Bool
    var disc_condition: String?
    var sleeve_condition: String?
    var photos: [Photo]
    let created_at: String
    let updated_at: String
}

struct RecordsResponse: Codable {
    let records: [VinylRecord]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - Input types

struct RecordInput: Encodable {
    var title: String
    var artist: String
    var year: Int?
    var duration: String?
    var label: String?
    var format: String?
    var speed: String?
    var genre: String?
    var notes: String?
    var owner: String
    var disc_count: Int
    var outer_sleeve_only: Bool
    var disc_condition: String?
    var sleeve_condition: String?
}

// MARK: - Constants

enum Formats {
    static let all = ["12\" LP", "10\" LP", "12\" single", "7\" single", "Other"]
}

enum Speeds {
    static let all = ["33", "45", "78"]
}

enum Grades {
    static let all = ["M", "NM", "VG+", "VG", "G+", "G", "F", "P"]
}

enum Owners {
    static let all = ["me", "dad", "shared"]
}

enum SleevePhotoType: String, CaseIterable {
    case sleeve_front        = "sleeve_front"
    case sleeve_back         = "sleeve_back"
    case sleeve_inner        = "sleeve_inner"
    case inner_sleeve_front  = "inner_sleeve_front"
    case inner_sleeve_back   = "inner_sleeve_back"

    var label: String {
        switch self {
        case .sleeve_front:       return "Front"
        case .sleeve_back:        return "Back"
        case .sleeve_inner:       return "Gatefold"
        case .inner_sleeve_front: return "Inner Sleeve (Front)"
        case .inner_sleeve_back:  return "Inner Sleeve (Back)"
        }
    }

    var isInnerOnly: Bool {
        self == .inner_sleeve_front || self == .inner_sleeve_back
    }
}

// MARK: - Collection filter

enum RecordTypeFilter: String, CaseIterable {
    case all     = "All"
    case lp      = "LPs"
    case singles = "Singles"

    func matches(_ record: VinylRecord) -> Bool {
        switch self {
        case .all:     return true
        case .lp:      return record.format?.contains("LP") == true
        case .singles: return record.format?.contains("single") == true
        }
    }
}
