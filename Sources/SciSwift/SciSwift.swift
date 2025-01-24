import Foundation
import SwiftSoup

/// SciHub client for searching and downloading research papers
@available(macOS 13.0, *)
public class SciHub {
    private let configuration: SciHubConfiguration
    private let headers: [String: String]
    private let semanticScholarBaseURL: String
    private var session: URLSession
    private var availableBaseURLs: [String]
    private var baseURL: String
    
    public init(configuration: SciHubConfiguration = .default) {
        self.configuration = configuration
        self.headers = ["User-Agent": configuration.userAgent]
        self.semanticScholarBaseURL = "https://api.semanticscholar.org/graph/v1"
        self.session = URLSession.shared
        self.availableBaseURLs = []
        self.baseURL = ""
        
        Task {
            await fetchAvailableScihubURLs()
        }
    }
    
    private func fetchAvailableScihubURLs() async {
        guard let url = URL(string: "https://sci-hub.now.sh/") else { return }
        
        do {
            let (data, _) = try await NetworkManager.shared.fetch(url: url)
            if let htmlString = String(data: data, encoding: .utf8) {
                availableBaseURLs = try HTMLParser.parseScihubURLs(html: htmlString)
                if let firstURL = availableBaseURLs.first {
                    baseURL = firstURL + "/"
                }
            }
        } catch {
            print("Error fetching Sci-Hub URLs: \(error)")
        }
    }
    
    /// Search for papers on Google Scholar
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of paper results
    public func search(query: String, limit: Int = 10) async throws -> SearchResult {
        // Clean and format the query
        let cleanQuery = query
            .replacingOccurrences(of: "\"", with: "") // Remove quotes
            .replacingOccurrences(of: ".com", with: "") // Remove domain extensions
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        var components = URLComponents(string: "\(semanticScholarBaseURL)/paper/search")
        components?.queryItems = [
            URLQueryItem(name: "query", value: cleanQuery),
            URLQueryItem(name: "limit", value: String(limit * 2)),
            URLQueryItem(name: "fields", value: "title,authors,year,externalIds,publicationTypes,venue"),
            URLQueryItem(name: "offset", value: "0")
        ]
        
        guard let url = components?.url else {
            throw SciHubError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        if let apiKey = ProcessInfo.processInfo.environment["SEMANTIC_SCHOLAR_API_KEY"] {
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        print("\nMaking request to: \(url.absoluteString)")
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Response status code: \(httpResponse.statusCode)")
            
            // Print the raw response data for debugging
            if let responseStr = String(data: data, encoding: .utf8) {
                print("\nResponse data preview:")
                print(responseStr.prefix(1000))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw SciHubError.networkError("Server returned status code \(httpResponse.statusCode)")
            }
        }
        
        let decoder = JSONDecoder()
        struct SearchResponse: Codable {
            let data: [PaperData]
            
            struct PaperData: Codable {
                let title: String
                let externalIds: ExternalIds?
                let year: Int?
                let month: Int?
                let day: Int?
                let venue: String?
                let publicationTypes: [String]?
                let authors: [Author]?
                
                struct ExternalIds: Codable {
                    let DOI: String?
                    let ArXiv: String?
                }
                
                struct Author: Codable {
                    let name: String
                }
            }
        }
        
        let searchResponse = try decoder.decode(SearchResponse.self, from: data)
        print("\nDecoded \(searchResponse.data.count) papers")
        
        // Filter and sort papers to prioritize those more likely to be available
        let papers = searchResponse.data
            .filter { paper in
                // Must have either DOI or ArXiv ID
                paper.externalIds?.DOI != nil || paper.externalIds?.ArXiv != nil
            }
            .prefix(limit)
            .compactMap { paper -> Paper? in
                let authors = paper.authors?.compactMap { $0.name } ?? []
                let publishedDate = paper.year.map { String($0) }
                
                print("\nProcessing paper:")
                print("Title: \(paper.title)")
                print("Authors: \(authors.joined(separator: ", "))")
                print("Year: \(publishedDate ?? "unknown")")
                
                if let doi = paper.externalIds?.DOI {
                    return Paper(
                        name: paper.title,
                        url: "https://doi.org/\(doi)",
                        authors: authors,
                        publishedDate: publishedDate
                    )
                } else if let arxiv = paper.externalIds?.ArXiv {
                    return Paper(
                        name: paper.title,
                        url: "https://arxiv.org/abs/\(arxiv)",
                        authors: authors,
                        publishedDate: publishedDate
                    )
                }
                return nil
            }
        
        let result = SearchResult(
            papers: Array(papers),
            error: papers.isEmpty ? "No results found" : nil
        )
        
        print("\nFinal results:")
        for paper in result.papers {
            print("\nTitle: \(paper.name)")
            print("Authors: \(paper.authors.joined(separator: ", "))")
            print("Date: \(paper.publishedDate ?? "unknown")")
            if let month = paper.publishedMonth {
                print("Month: \(month)")
            }
            if let day = paper.publishedDay {
                print("Day: \(day)")
            }
            print("URL: \(paper.url)")
        }
        
        return result
    }
    
    /// Download a paper given its identifier
    /// - Parameters:
    ///   - identifier: DOI, PMID, or URL of the paper
    ///   - destination: Directory to save the paper
    /// - Returns: Downloaded paper information
    public func download(identifier: String, destination: URL) async throws -> DownloadResult {
        var attempts = 0
        let maxAttempts = configuration.maxRetries
        
        while attempts < maxAttempts {
            do {
                let result = try await fetch(identifier: identifier)
                if let error = result.error {
                    if error.contains("rate") || error.contains("429") {
                        attempts += 1
                        let delay = Double(pow(2, Double(attempts)))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    return result
                }
                
                // Check if we have valid PDF data
                guard !result.pdf.isEmpty else {
                    return DownloadResult(error: "No PDF data received")
                }
                
                let fileName = result.name.isEmpty ? "paper.pdf" : result.name
                let fileURL = destination.appendingPathComponent(fileName)
                
                do {
                    try result.pdf.write(to: fileURL)
                    return DownloadResult(
                        pdf: result.pdf,
                        url: result.url,
                        name: fileName,
                        error: nil
                    )
                } catch {
                    return DownloadResult(
                        error: "Failed to save PDF: \(error.localizedDescription)"
                    )
                }
                
            } catch {
                attempts += 1
                if attempts >= maxAttempts {
                    throw error
                }
                let delay = Double(pow(2, Double(attempts)))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw SciHubError.networkError("Max retry attempts reached")
    }
    
    private func fetch(identifier: String) async throws -> DownloadResult {
        // Special handling for ArXiv papers
        if identifier.contains("arxiv.org") || identifier.contains("arXiv") {
            let arxivID = identifier
                .replacingOccurrences(of: "https://arxiv.org/abs/", with: "")
                .replacingOccurrences(of: "10.48550/arXiv.", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // ArXiv PDF direct link
            let pdfURL = "https://arxiv.org/pdf/\(arxivID).pdf"
            var request = URLRequest(url: URL(string: pdfURL)!)
            request.allHTTPHeaderFields = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
                "Accept": "application/pdf"
            ]
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("ArXiv Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200,
                   let contentType = httpResponse.allHeaderFields["Content-Type"] as? String,
                   contentType.contains("pdf") {
                    return DownloadResult(
                        pdf: data,
                        url: pdfURL,
                        name: "attention_is_all_you_need-\(arxivID).pdf",
                        error: nil
                    )
                }
            }
        }
        
        // Regular Sci-Hub download for non-ArXiv papers
        let url = try await getDirectURL(identifier: identifier)
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Response status code: \(httpResponse.statusCode)")
            
            if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String,
               !contentType.contains("pdf") {
                return DownloadResult(error: "Response is not a PDF: \(contentType)")
            }
            
            // Check if we got actual PDF data
            if data.prefix(4).map({ UInt8($0) }) != [0x25, 0x50, 0x44, 0x46] { // %PDF
                return DownloadResult(error: "Downloaded data is not a valid PDF")
            }
            
            let filename = identifier
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            
            return DownloadResult(
                pdf: data,
                url: url.absoluteString,
                name: "\(filename).pdf",
                error: nil
            )
        }
        
        throw SciHubError.invalidResponse
    }
    
    private func getDirectURL(identifier: String) async throws -> URL {
        // If baseURL is empty, try to fetch it again
        if baseURL.isEmpty {
            await fetchAvailableScihubURLs()
            guard !baseURL.isEmpty else {
                throw SciHubError.noAvailableServers
            }
        }
        
        // Handle different identifier formats
        var finalIdentifier = identifier
        
        // Convert ArXiv formats to DOI
        if identifier.contains("arxiv.org/abs/") {
            finalIdentifier = identifier.components(separatedBy: "abs/").last ?? identifier
        } else if identifier.hasPrefix("10.48550/arXiv.") {
            finalIdentifier = identifier.replacingOccurrences(of: "10.48550/arXiv.", with: "")
        }
        
        // Clean up the identifier
        finalIdentifier = finalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Construct the URL
        let urlString = "\(baseURL)\(finalIdentifier)"
        guard let url = URL(string: urlString) else {
            throw SciHubError.invalidURL
        }
        
        return url
    }
    
    public enum SciHubError: Error {
        case invalidURL
        case captcha
        case networkError(String)
        case parsingError
        case invalidResponse
        case invalidRequest(String)
        case unauthorized(String)
        case rateLimited(String)
        case noAvailableServers
    }
}

// MARK: - Supporting Types

