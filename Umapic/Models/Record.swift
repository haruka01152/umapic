import Foundation
import CoreLocation

struct Record: Identifiable, Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Record, rhs: Record) -> Bool {
        lhs.id == rhs.id
    }
    let id: String
    let storeName: String
    let placeId: String?
    let latitude: Double
    let longitude: Double
    let address: String?
    let visitDate: Date
    let rating: Double
    let note: String?
    let companions: [String]
    let thumbnailUrl: String?  // リスト取得時
    let photos: [Photo]?       // 詳細取得時
    let createdAt: Date
    let updatedAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id = "recordId"
        case storeName
        case placeId
        case latitude
        case longitude
        case address
        case visitDate
        case rating
        case note
        case companions
        case thumbnailUrl
        case photos
        case createdAt
        case updatedAt
    }
}

struct Photo: Codable, Equatable {
    let key: String?  // S3キー（編集時に必要）
    let originalUrl: String
    let thumbnailUrl: String
}

extension Record {
    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let simpleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        storeName = try container.decode(String.self, forKey: .storeName)
        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        rating = try container.decode(Double.self, forKey: .rating)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        companions = try container.decodeIfPresent([String].self, forKey: .companions) ?? []
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        photos = try container.decodeIfPresent([Photo].self, forKey: .photos)

        // 日付のデコード
        let visitDateString = try container.decode(String.self, forKey: .visitDate)
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        if let date = Self.dateFormatter.date(from: visitDateString) {
            visitDate = date
        } else {
            visitDate = Self.simpleDateFormatter.date(from: visitDateString) ?? Date()
        }

        createdAt = Self.dateFormatter.date(from: createdAtString) ?? Date()
        if let updatedAtString = updatedAtString {
            updatedAt = Self.dateFormatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
}

#if DEBUG
extension Record {
    static let previewSample = Record(
        id: "preview001",
        storeName: "サンプル店舗",
        placeId: nil,
        latitude: 35.6812,
        longitude: 139.7671,
        address: "東京都千代田区",
        visitDate: Date(),
        rating: 4.0,
        note: "プレビュー用サンプル",
        companions: [],
        thumbnailUrl: nil,
        photos: nil,
        createdAt: Date(),
        updatedAt: nil
    )
}
#endif
