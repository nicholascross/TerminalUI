import Foundation

/// Thread-local because the ordinary renderer also supports terminal-independent, non-actor callers.
package enum UIEvaluationPhase {
    private static let key = "TerminalUI.evaluationPhase"
    package static var current: String? {
        Thread.current.threadDictionary[key] as? String
    }

    package static func perform<Result>(_ phase: String, _ work: () throws -> Result) rethrows -> Result {
        let previous = Thread.current.threadDictionary[key]
        Thread.current.threadDictionary[key] = phase
        defer { Thread.current.threadDictionary[key] = previous }
        return try work()
    }
}
