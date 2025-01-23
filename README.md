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
    .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
]
```

## Usage

```swift
import SciSwift

let sciHub = SciHub()
let searchResult = await sciHub.search(query: "machine learning")
print(searchResult)
```

