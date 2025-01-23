import Foundation

public struct SciHubConfiguration {
    public var timeout: TimeInterval
    public var maxRetries: Int
    public var userAgent: String
    
    public static let `default` = SciHubConfiguration()
    
    public init(
        timeout: TimeInterval = 30,
        maxRetries: Int = 3,
        userAgent: String = "Mozilla/5.0 (X11; Linux x86_64; rv:27.0) Gecko/20100101 Firefox/27.0"
    ) {
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.userAgent = userAgent
    }
} 