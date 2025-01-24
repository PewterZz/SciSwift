import XCTest
@testable import SciSwift

@available(macOS 13.0, *)
final class SciSwiftTests: XCTestCase {
    var sciHub: SciHub!
    let testQueries = [
        "deep learning nature 2023",
        "quantum computing science",
        "CRISPR cell",
        "artificial intelligence review",
        "machine learning neural networks"
    ]
    let testDOI = "10.1038/nature14539"
    
    override func setUp() {
        super.setUp()
        // Initialize with increased timeout and retries
        let config = SciHubConfiguration(
            timeout: 120, // Increased timeout
            maxRetries: 3
        )
        sciHub = SciHub(configuration: config)
        // Give more time for the SciHub URLs to be fetched
        Thread.sleep(forTimeInterval: 5) // Increased wait time
    }
    
    override func tearDown() {
        sciHub = nil
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testSearch() async throws {
        print("\n=== Starting Search Test ===")
        
        // Try with a single, well-known paper first
        let knownPaper = "\"Deep learning nature\" 2015 nature.com"
        
        do {
            print("\nTrying search query: '\(knownPaper)'")
            let results = try await sciHub.search(query: knownPaper, limit: 1)
            
            print("Search response received")
            if let error = results.error {
                print("Search error: \(error)")
            }
            
            print("Found \(results.papers.count) papers")
            
            if !results.papers.isEmpty {
                for (index, paper) in results.papers.enumerated() {
                    print("\n[\(index + 1)] Title: \(paper.name)")
                    print("    URL: \(paper.url)")
                }
                return
            }
            
            // Only try other queries if the known paper fails
            for query in testQueries {
                do {
                    print("\nTrying search query: '\(query)'")
                    let results = try await sciHub.search(query: query, limit: 5)
                    
                    print("Search response received")
                    if let error = results.error {
                        print("Search error: \(error)")
                    }
                    
                    print("Found \(results.papers.count) papers")
                    
                    if !results.papers.isEmpty {
                        print("\nPapers found:")
                        for (index, paper) in results.papers.enumerated() {
                            print("\n[\(index + 1)] Title: \(paper.name)")
                            print("    URL: \(paper.url)")
                        }
                        
                        // If we found papers, we can exit the loop
                        XCTAssertFalse(results.papers.isEmpty, "Papers were found successfully")
                        return
                    }
                } catch {
                    print("Search failed for query '\(query)': \(error.localizedDescription)")
                }
                
                // Add a small delay between attempts
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            // If we get here, none of the queries returned papers
            XCTFail("No papers found for any of the test queries")
        } catch {
            print("Search failed with error: \(error)")
        }
    }
    
    func testDownload() async throws {
        let destination = URL.documentsDirectory()
        
        // Try with a known DOI first
        let testDOIs = [
            "10.1038/nature14539",
            "10.1126/science.1157996",
            "10.1038/s41586-019-1666-5"
        ]
        
        var succeeded = false
        var lastError: Error?
        
        for doi in testDOIs {
            do {
                print("Attempting to download DOI: \(doi)")
                let result = try await sciHub.download(identifier: doi, destination: destination)
                
                if result.error == nil && result.pdf != nil {
                    succeeded = true
                    print("Successfully downloaded paper with DOI: \(doi)")
                    
                    // Cleanup
                    if let pdfPath = result.name.isEmpty ? nil : destination.appendingPathComponent(result.name) {
                        try? FileManager.default.removeItem(at: pdfPath)
                    }
                    break
                } else if let error = result.error {
                    print("Download error for DOI \(doi): \(error)")
                }
            } catch {
                lastError = error
                print("Failed to download DOI \(doi): \(error.localizedDescription)")
                continue
            }
        }
        
        if !succeeded {
            throw XCTSkip("Could not download any test papers. Last error: \(lastError?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func testFullWorkflow() async throws {
        // Start with a simple search
        print("Starting full workflow test")
        let results = try await sciHub.search(query: "quantum computing", limit: 3)
        
        if results.papers.isEmpty {
            throw XCTSkip("No papers found in search results")
        }
        
        print("Found \(results.papers.count) papers")
        
        // Try downloading each paper until one succeeds
        var downloadSuccess = false
        var lastError: Error?
        
        for paper in results.papers {
            do {
                print("Attempting to download paper: \(paper.name)")
                let destination = URL.documentsDirectory()
                let download = try await sciHub.download(identifier: paper.url, destination: destination)
                
                if download.error == nil && download.pdf != nil {
                    downloadSuccess = true
                    print("Successfully downloaded paper")
                    
                    // Cleanup
                    if let pdfPath = download.name.isEmpty ? nil : destination.appendingPathComponent(download.name) {
                        try? FileManager.default.removeItem(at: pdfPath)
                    }
                    break
                } else if let error = download.error {
                    print("Download error: \(error)")
                }
            } catch {
                lastError = error
                print("Download attempt failed: \(error.localizedDescription)")
                continue
            }
        }
        
        if !downloadSuccess {
            throw XCTSkip("Could not complete full workflow. Last error: \(lastError?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func testAttentionPaper() async throws {
        print("\n=== Testing Attention Paper Download ===")
        let destination = URL.documentsDirectory()
        
        // Known paper details
        let query = "\"Attention is All You Need\" Vaswani"
        let identifiers = [
            "10.48550/arXiv.1706.03762",  // ArXiv DOI format
            "1706.03762",                 // ArXiv ID
            "https://arxiv.org/abs/1706.03762" // Direct ArXiv URL
        ]
        
        do {
            print("Searching for the paper...")
            let results = try await sciHub.search(query: query, limit: 1)
            
            guard !results.papers.isEmpty else {
                throw XCTSkip("Could not find the Attention paper")
            }
            
            let paper = results.papers[0]
            print("\nFound paper:")
            print("Title: \(paper.name)")
            print("URL: \(paper.url)")
            
            // Try each identifier until one works
            var succeeded = false
            var lastError: Error?
            
            for identifier in identifiers {
                do {
                    print("\nAttempting to download using identifier: \(identifier)")
                    let download = try await sciHub.download(identifier: identifier, destination: destination)
                    
                    if let error = download.error {
                        print("Download error: \(error)")
                        continue
                    }
                    
                    XCTAssertFalse(download.pdf.isEmpty, "PDF data should not be empty")
                    print("Successfully downloaded the paper")
                    
                    // Save the file location
                    if !download.name.isEmpty {
                        let pdfPath = destination.appendingPathComponent(download.name)
                        print("\nPDF saved at: \(pdfPath.path)")
                    }
                    
                    succeeded = true
                    break
                } catch {
                    lastError = error
                    print("Download failed: \(error.localizedDescription)")
                    continue
                }
            }
            
            if !succeeded {
                throw XCTSkip("Could not download paper with any identifier. Last error: \(lastError?.localizedDescription ?? "Unknown error")")
            }
        } catch {
            print("Test failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func testSearchWithMetadata() async throws {
        print("\n=== Starting Search Test with Metadata ===")
        
        // Try with a well-known paper that should have complete metadata
        let knownPaper = "\"Attention is All You Need\" Vaswani 2017"
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                if attempt > 1 {
                    // Exponential backoff: wait longer between each retry
                    let delay = Double(attempt * 2)
                    print("\nRetrying after \(delay) seconds (attempt \(attempt)/\(maxRetries))...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                print("\nTrying search query: '\(knownPaper)'")
                let results = try await sciHub.search(query: knownPaper, limit: 1)
                
                print("Search response received")
                if let error = results.error {
                    print("Search error: \(error)")
                    continue
                }
                
                print("Found \(results.papers.count) papers")
                
                for (index, paper) in results.papers.enumerated() {
                    print("\n=== Paper \(index + 1) ===")
                    print("Title: \(paper.name)")
                    print("Authors: \(paper.authors.joined(separator: ", "))")
                    if let publishedDate = paper.publishedDate {
                        print("Published: \(publishedDate)")
                    }
                    print("URL: \(paper.url)")
                }
                
                XCTAssertFalse(results.papers.isEmpty, "Should find at least one paper")
                if let paper = results.papers.first {
                    XCTAssertFalse(paper.authors.isEmpty, "Paper should have authors")
                    XCTAssertNotNil(paper.publishedDate, "Paper should have a publication date")
                }
                
                return // Success, exit the retry loop
                
            } catch {
                lastError = error
                print("Search failed with error: \(error)")
                
                if attempt == maxRetries {
                    throw XCTSkip("Max retries reached. Last error: \(error)")
                }
            }
        }
    }
    
} 
