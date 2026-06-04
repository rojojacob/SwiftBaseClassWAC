//
//  AppLogger.swift
//  SwiftBaseClassWAC
//
//  Thin wrapper over the unified logging system (OSLog). Use category-scoped
//  loggers (`.network`, `.ui`, …) so logs are filterable in Console.app.
//

import Foundation
import OSLog

struct AppLogger {
    private let logger: Logger

    init(category: String, subsystem: String = Bundle.main.bundleIdentifier ?? "SwiftBaseClassWAC") {
        logger = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    /// Logs an error value with an optional contextual message.
    func error(_ error: any Error, _ message: String? = nil) {
        if let message {
            logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(error.localizedDescription, privacy: .public)")
        }
    }
}

extension AppLogger {
    static let app = AppLogger(category: "app")
    static let network = AppLogger(category: "network")
    static let ui = AppLogger(category: "ui")
}
