import Foundation
import SwiftSoup

struct HTMLParser {
    static func parseGoogleScholar(html: String) throws -> [Paper] {
        let doc = try SwiftSoup.parse(html)
        var papers: [Paper] = []
        
        print("Parsing HTML content length: \(html.count)")
        print("\nHTML Content Preview:")
        print(html.prefix(1000))  // Print first 1000 chars for debugging
        
        // First check if we're being blocked
        let captchaCheck = try doc.select("div#gs_captcha").first()
        if captchaCheck != nil {
            print("CAPTCHA detected - Google Scholar is blocking our requests")
            return papers
        }
        
        // Try to find results container first
        let containers = try doc.select("div#gs_res_ccl_mid, div#gs_results, div#gs_ccl")
        print("Found \(containers.count) result containers")
        
        if let container = containers.first() {
            // Look for any divs that might contain results
            let results = try container.select("div[data-cid], div.gs_r, div.gs_ri, div.gsc_rsb")
            print("Found \(results.count) potential result elements")
            
            for result in results {
                print("\nProcessing result element:")
                print(try result.html())
                
                // Try multiple ways to extract title and URL
                var title: String? = nil
                var url: String? = nil
                
                // Method 1: Direct title link
                if let titleLink = try? result.select("a").first() {
                    title = try? titleLink.text()
                    url = try? titleLink.attr("href")
                    print("Method 1 - Title: \(title ?? "nil"), URL: \(url ?? "nil")")
                }
                
                // Method 2: Structured data
                if title == nil {
                    if let dataTitle = try? result.attr("data-title") {
                        title = dataTitle
                        url = try? result.attr("data-href")
                        print("Method 2 - Title: \(title ?? "nil"), URL: \(url ?? "nil")")
                    }
                }
                
                // Method 3: Citation info
                if url == nil {
                    if let citation = try? result.select("div.gs_a").first()?.text() {
                        if let doi = extractDOI(from: citation) {
                            url = "https://doi.org/\(doi)"
                            print("Method 3 - Found DOI URL: \(url ?? "nil")")
                        }
                    }
                }
                
                // If we found both title and URL, add the paper
                if let finalTitle = title, let finalURL = url {
                    papers.append(Paper(name: finalTitle, url: finalURL))
                    print("Added paper: \(finalTitle)")
                }
            }
        }
        
        // Print final results
        print("\nFound \(papers.count) papers total")
        papers.forEach { paper in
            print("- \(paper.name)")
            print("  URL: \(paper.url)")
        }
        
        return papers
    }
    
    private static func extractDOI(from text: String) -> String? {
        let pattern = "10.\\d{4,9}/[-._;()/:A-Z0-9]+"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            return String(text[Range(match.range, in: text)!])
        }
        return nil
    }
    
    static func parseSciHub(html: String) throws -> String? {
        let doc = try SwiftSoup.parse(html)
        if let iframe = try doc.select("iframe").first() {
            var src = try iframe.attr("src")
            if src.starts(with: "//") {
                src = "http:" + src
            }
            return src
        }
        return nil
    }
    
    static func parseScihubURLs(html: String) throws -> [String] {
        let doc = try SwiftSoup.parse(html)
        return try doc.select("a[href]")
            .compactMap { try? $0.attr("href") }
            .filter { $0.contains("sci-hub.") }
    }
} 