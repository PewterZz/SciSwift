# SciSwift

A Swift package for searching and downloading research papers from various academic sources.

## Features

- Search papers on Google Scholar
- Download papers from Sci-Hub
- Support for DOI, PMID, and direct URLs
- Automatic retry mechanism
- Async/await support

## Installation

Add this package to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/PewterZz/SciSwift.git", from: "1.0.0"),
]
```

## Usage

```swift
import SciSwift

// Initialize SciSwift with optional configuration
let sciSwift = SciSwift()

// Search for papers
let searchResults = try await sciSwift.searchScholar(query: "machine learning")
for result in searchResults {
    print(result.title)
    print(result.authors)
    print(result.url)
}

// Download a paper using DOI
let pdfData = try await sciSwift.downloadPaper(doi: "10.1234/example.doi")

// Download a paper using URL
let paperURL = "https://example.com/paper.pdf"
let pdfData = try await sciSwift.downloadPaper(url: paperURL)
```

