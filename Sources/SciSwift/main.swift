import Foundation

guard #available(macOS 13.0, *) else {
    print("This app requires macOS 13.0 or later")
    exit(1)
}

// Create SciHub instance
let sciHub = SciHub()

print("Starting SciHub test...")

// Test function
func testSciHub() async {
    do {
        // Try to search for papers
        print("Searching for papers...")
        let results = try await sciHub.search(query: "machine learning", limit: 2)
        
        if let error = results.error {
            print("Search error: \(error)")
            return
        }
        
        print("Found \(results.papers.count) papers:")
        for paper in results.papers {
            print("\nTitle: \(paper.name)")
            print("URL: \(paper.url)")
            
            // Try to download the first paper
            print("\nTrying to download...")
            let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let download = try await sciHub.download(identifier: paper.url, destination: destination)
            
            if let error = download.error {
                print("Download error: \(error)")
            } else {
                print("Successfully downloaded to: \(download.name)")
            }
        }
    } catch {
        print("Error: \(error)")
    }
}

// Run the test
Task {
    await testSciHub()
    exit(0)
}

// Keep the program running until the task completes
RunLoop.main.run() 