import Foundation

// MARK: - Generic API Response
struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

struct APIErrorResponse: Decodable {
    let error: APIError
}

struct APIError: Decodable, Error {
    let code: String
    let message: String
    let details: [String: String]?
}

// MARK: - Records Response
struct RecordsResponse: Decodable {
    let records: [Record]
    let nextCursor: String?
    let hasMore: Bool
}

struct CreateRecordResponse: Decodable {
    let recordId: String
    let createdAt: String
}

struct UpdateRecordResponse: Decodable {
    let recordId: String
    let updatedAt: String
}

// MARK: - S3 Upload URL Response
struct S3UploadURLResponse: Decodable {
    let recordId: String
    let uploadUrls: [UploadURL]
}

struct UploadURL: Decodable {
    let index: Int
    let uploadUrl: String
    let key: String
    let expiresAt: String
}

// MARK: - Place Search Response
struct PlacesResponse: Decodable {
    let places: [Place]
}

struct Place: Decodable, Identifiable, Hashable {
    let placeId: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let types: [String]?
    let rating: Double?
    let priceLevel: Int?

    var id: String { placeId }

    func hash(into hasher: inout Hasher) {
        hasher.combine(placeId)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.placeId == rhs.placeId
    }
}
