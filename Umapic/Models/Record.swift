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
    let userId: String
    let storeName: String
    let placeId: String?
    let latitude: Double
    let longitude: Double
    let address: String?
    let visitDate: Date
    let rating: Double
    let note: String?
    let companions: [String]
    let photoKeys: [String]
    let createdAt: Date
    let updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id = "recordId"
        case userId
        case storeName
        case placeId
        case latitude
        case longitude
        case address
        case visitDate
        case rating
        case note
        case companions
        case photoKeys
        case createdAt
        case updatedAt
    }
}

extension Record {
    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        storeName = try container.decode(String.self, forKey: .storeName)
        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        rating = try container.decode(Double.self, forKey: .rating)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        companions = try container.decodeIfPresent([String].self, forKey: .companions) ?? []
        photoKeys = try container.decodeIfPresent([String].self, forKey: .photoKeys) ?? []

        // 日付のデコード
        let visitDateString = try container.decode(String.self, forKey: .visitDate)
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)

        if let date = Self.dateFormatter.date(from: visitDateString) {
            visitDate = date
        } else {
            // YYYY-MM-DD形式の場合
            let simpleFormatter = DateFormatter()
            simpleFormatter.dateFormat = "yyyy-MM-dd"
            visitDate = simpleFormatter.date(from: visitDateString) ?? Date()
        }

        createdAt = Self.dateFormatter.date(from: createdAtString) ?? Date()
        updatedAt = Self.dateFormatter.date(from: updatedAtString) ?? Date()
    }
}

// MARK: - Mock Data
extension Record {
    static let mockRecords: [Record] = [
        Record(
            id: "rec001",
            userId: "user001",
            storeName: "ラーメン二郎 渋谷店",
            placeId: "ChIJN1t_tDeuEmsRUsoyG83frY4",
            latitude: 35.6594945,
            longitude: 139.7005536,
            address: "東京都渋谷区道玄坂1-2-3",
            visitDate: Date().addingTimeInterval(-86400 * 3),
            rating: 4.5,
            note: "野菜マシマシで最高だった！また来たい。",
            companions: ["友人"],
            photoKeys: ["photos/user001/rec001/1.jpg"],
            createdAt: Date().addingTimeInterval(-86400 * 3),
            updatedAt: Date().addingTimeInterval(-86400 * 3)
        ),
        Record(
            id: "rec002",
            userId: "user001",
            storeName: "スターバックス 新宿南口店",
            placeId: nil,
            latitude: 35.6896342,
            longitude: 139.6994286,
            address: "東京都新宿区西新宿1-1-1",
            visitDate: Date().addingTimeInterval(-86400 * 7),
            rating: 4.0,
            note: "新作フラペチーノを試した",
            companions: [],
            photoKeys: ["photos/user001/rec002/1.jpg"],
            createdAt: Date().addingTimeInterval(-86400 * 7),
            updatedAt: Date().addingTimeInterval(-86400 * 7)
        ),
        Record(
            id: "rec003",
            userId: "user001",
            storeName: "焼肉きんぐ 目黒店",
            placeId: nil,
            latitude: 35.6332635,
            longitude: 139.7156229,
            address: "東京都目黒区自由が丘1-2-3",
            visitDate: Date().addingTimeInterval(-86400 * 14),
            rating: 5.0,
            note: "食べ放題最高！家族で大満足。",
            companions: ["家族"],
            photoKeys: ["photos/user001/rec003/1.jpg", "photos/user001/rec003/2.jpg"],
            createdAt: Date().addingTimeInterval(-86400 * 14),
            updatedAt: Date().addingTimeInterval(-86400 * 14)
        )
    ]
}
