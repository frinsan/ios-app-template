import Foundation

struct APIClient {
    let baseURL: URL
    let session: URLSession = .shared

    func perform<T: Decodable>(_ request: APIRequest<T>) async throws -> T {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(request.path))
        urlRequest.httpMethod = request.method
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            throw APIError.responseError
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct APIRequest<T: Decodable> {
    var path: String
    var method: String = "GET"
    var headers: [String: String] = [:]
    var body: Data? = nil
}

enum APIError: Error {
    case responseError
}
