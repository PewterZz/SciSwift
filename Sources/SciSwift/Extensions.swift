import Foundation

extension String {
    var isValidDOI: Bool {
        // Basic DOI validation
        let pattern = "^10.\\d{4,9}/[-._;()/:a-zA-Z0-9]+$"
        return range(of: pattern, options: .regularExpression) != nil
    }
    
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }
}

extension URL {
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func appendingQueryItems(_ queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        return components?.url ?? self
    }
} 