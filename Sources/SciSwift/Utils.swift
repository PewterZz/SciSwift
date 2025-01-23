import Foundation
import CryptoKit

enum IDType {
    case urlDirect
    case urlNonDirect
    case pmid
    case doi
}

struct Utils {
    static func classifyIdentifier(_ identifier: String) -> IDType {
        if identifier.hasPrefix("http") || identifier.hasPrefix("https") {
            if identifier.hasSuffix("pdf") {
                return .urlDirect
            }
            return .urlNonDirect
        } else if identifier.allSatisfy({ $0.isNumber }) {
            return .pmid
        }
        return .doi
    }
    
    static func generateFileName(url: String, data: Data) -> String {
        let name = url.components(separatedBy: "/").last ?? ""
        let cleanName = name.replacingOccurrences(of: "#view=.+", with: "", options: .regularExpression)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        return "\(hashString)-\(String(cleanName.suffix(20)))"
    }
    
    static func savePDF(_ data: Data, to directory: URL, filename: String) throws {
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL)
    }
} 