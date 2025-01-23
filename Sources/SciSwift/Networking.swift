import Foundation

class NetworkManager {
    static var shared = NetworkManager()
    
    private var session: URLSession
    private var configuration: SciHubConfiguration
    
    func updateConfiguration(_ config: SciHubConfiguration) {
        self.configuration = config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 2
        session = URLSession(configuration: sessionConfig)
    }
    
    init(configuration: SciHubConfiguration = .default) {
        self.configuration = configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        session = URLSession(configuration: sessionConfig)
    }
    
    func fetch(url: URL) async throws -> (Data, URLResponse) {
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                return try await session.data(from: url)
            } catch {
                retryCount += 1
                if retryCount == maxRetries {
                    throw NetworkError.maxRetriesExceeded
                }
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
            }
        }
        
        throw NetworkError.unknown
    }
    
    func download(from url: URL) async throws -> Data {
        let (data, response) = try await fetch(url: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return data
    }
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case maxRetriesExceeded
    case unknown
} 