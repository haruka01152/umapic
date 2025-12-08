import Foundation

struct CreateRecordRequest: Encodable {
    let storeName: String?
    let placeId: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let visitDate: String
    let rating: Double?
    let note: String?
    let companions: [String]
    let photoKeys: [String]

    init(
        storeName: String? = nil,
        placeId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        visitDate: Date,
        rating: Double? = nil,
        note: String? = nil,
        companions: [String] = [],
        photoKeys: [String] = []
    ) {
        self.storeName = storeName
        self.placeId = placeId
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.rating = rating
        self.note = note
        self.companions = companions
        self.photoKeys = photoKeys

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.visitDate = formatter.string(from: visitDate)
    }
}

struct UpdateRecordRequest: Encodable {
    var storeName: String?
    var visitDate: String?
    var rating: Double?
    var note: String?
    var companions: [String]?
    var photoKeys: [String]?
}
