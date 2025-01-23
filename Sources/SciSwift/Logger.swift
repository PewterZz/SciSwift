import Foundation
import os.log

class Logger {
    static let shared = Logger()
    private let logger: OSLog
    
    private init() {
        self.logger = OSLog(subsystem: "com.scihub.swift", category: "SciHub")
    }
    
    func debug(_ message: String) {
        os_log(.debug, log: logger, "%{public}@", message)
    }
    
    func info(_ message: String) {
        os_log(.info, log: logger, "%{public}@", message)
    }
    
    func error(_ message: String) {
        os_log(.error, log: logger, "%{public}@", message)
    }
} 