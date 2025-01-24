import Foundation

public struct SearchResult {
    public let papers: [Paper]
    public let error: String?
    
    public init(papers: [Paper] = [], error: String? = nil) {
        self.papers = papers
        self.error = error
    }
}

public struct Paper: Codable {
    public let name: String
    public let url: String
    public let authors: [String]
    public let publishedDate: String?
    public let publishedMonth: Int?
    public let publishedDay: Int?
    
    public init(name: String, url: String, authors: [String] = [], publishedDate: String? = nil, publishedMonth: Int? = nil, publishedDay: Int? = nil) {
        self.name = name
        self.url = url
        self.authors = authors
        self.publishedDate = publishedDate
        self.publishedMonth = publishedMonth
        self.publishedDay = publishedDay
    }
}

public struct DownloadResult {
    public let pdf: Data
    public let url: String
    public let name: String
    public let error: String?
    
    public init(pdf: Data? = nil, url: String = "", name: String = "", error: String? = nil) {
        self.pdf = pdf ?? Data()
        self.url = url
        self.name = name
        self.error = error
    }
} 