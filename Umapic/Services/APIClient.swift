import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let userIdManager = UserIdManager()
    private let decoder: JSONDecoder

    private init() {
        // AWS API Gateway endpoint
        baseURL = URL(string: "https://6yeb92jo2f.execute-api.ap-northeast-1.amazonaws.com/v1")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
    }

    // MARK: - Records API

    func fetchRecords(
        sort: String = "visitDate",
        order: String = "desc",
        limit: Int = 20,
        cursor: String? = nil,
        keyword: String? = nil
    ) async throws -> RecordsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("records"), resolvingAgainstBaseURL: false)!

        var queryItems = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "order", value: order),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        if let keyword = keyword {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }

        components.queryItems = queryItems

        let request = try makeRequest(url: components.url!, method: "GET")
        let response: APIResponse<RecordsResponse> = try await performRequest(request)
        return response.data
    }

    func fetchRecord(id: String) async throws -> Record {
        let url = baseURL.appendingPathComponent("records/\(id)")
        let request = try makeRequest(url: url, method: "GET")
        let response: APIResponse<Record> = try await performRequest(request)
        return response.data
    }

    func createRecord(_ record: CreateRecordRequest) async throws -> CreateRecordResponse {
        let url = baseURL.appendingPathComponent("records")
        var request = try makeRequest(url: url, method: "POST")
        request.httpBody = try JSONEncoder().encode(record)
        let response: APIResponse<CreateRecordResponse> = try await performRequest(request)
        return response.data
    }

    func updateRecord(id: String, _ record: UpdateRecordRequest) async throws -> UpdateRecordResponse {
        let url = baseURL.appendingPathComponent("records/\(id)")
        var request = try makeRequest(url: url, method: "PUT")
        request.httpBody = try JSONEncoder().encode(record)
        let response: APIResponse<UpdateRecordResponse> = try await performRequest(request)
        return response.data
    }

    func deleteRecord(id: String) async throws {
        let url = baseURL.appendingPathComponent("records/\(id)")
        let request = try makeRequest(url: url, method: "DELETE")
        _ = try await session.data(for: request)
    }

    // MARK: - S3 Upload URL

    func getUploadURLs(count: Int = 1, recordId: String? = nil) async throws -> S3UploadURLResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("s3-upload-url"), resolvingAgainstBaseURL: false)!

        var queryItems = [URLQueryItem(name: "count", value: String(count))]
        if let recordId = recordId {
            queryItems.append(URLQueryItem(name: "recordId", value: recordId))
        }
        components.queryItems = queryItems

        let request = try makeRequest(url: components.url!, method: "GET")
        let response: APIResponse<S3UploadURLResponse> = try await performRequest(request)
        return response.data
    }

    func uploadImage(data: Data, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError(code: "UPLOAD_FAILED", message: "画像のアップロードに失敗しました", details: nil)
        }
    }

    // MARK: - Places API

    func searchPlaces(
        query: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Int = 5000
    ) async throws -> PlacesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("places/search"), resolvingAgainstBaseURL: false)!

        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "radius", value: String(radius))
        ]

        if let lat = latitude, let lng = longitude {
            queryItems.append(URLQueryItem(name: "latitude", value: String(lat)))
            queryItems.append(URLQueryItem(name: "longitude", value: String(lng)))
        }

        components.queryItems = queryItems

        let request = try makeRequest(url: components.url!, method: "GET")
        let response: APIResponse<PlacesResponse> = try await performRequest(request)
        return response.data
    }

    // MARK: - Private Methods

    private func makeRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userIdManager.getOrCreateUserId(), forHTTPHeaderField: "X-User-ID")
        return request
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(code: "INVALID_RESPONSE", message: "無効なレスポンスです", details: nil)
        }

        // エラーレスポンスの処理
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw errorResponse.error
            }
            throw APIError(
                code: "HTTP_ERROR",
                message: "HTTPエラー: \(httpResponse.statusCode)",
                details: nil
            )
        }

        return try decoder.decode(T.self, from: data)
    }
}
