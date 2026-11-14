import Foundation
@testable import TerminalUIRuntime
import Testing

struct EscapeDeadlineTests {
    @Test func `escape deadline restarts on input and expires once`() {
        let clock = ManualClock()
        var deadline = EscapeDeadline(clock: clock, milliseconds: 20)
        #expect(deadline.pollTimeout == 20)
        clock.advance(by: .seconds(1))
        let beforeInput = deadline.consumeIfExpired()
        #expect(!beforeInput)
        deadline.receivedInput()
        clock.advance(by: .milliseconds(19))
        let beforeDeadline = deadline.consumeIfExpired()
        #expect(!beforeDeadline)
        deadline.receivedInput()
        clock.advance(by: .milliseconds(19))
        let afterRestart = deadline.consumeIfExpired()
        #expect(!afterRestart)
        clock.advance(by: .milliseconds(1))
        let atDeadline = deadline.consumeIfExpired()
        #expect(atDeadline)
        let afterConsumption = deadline.consumeIfExpired()
        #expect(!afterConsumption)
    }

    @Test func `escape configuration bounds the deadline and poll interval`() {
        let clock = ManualClock()
        var short = EscapeDeadline(clock: clock, milliseconds: -1)
        var long = EscapeDeadline(clock: clock, milliseconds: Int.max)
        #expect(short.pollTimeout == 1)
        #expect(long.pollTimeout == 30)
        short.receivedInput()
        long.receivedInput()
        clock.advance(by: .milliseconds(1))
        let shortExpired = short.consumeIfExpired()
        #expect(shortExpired)
        clock.advance(by: .milliseconds(4998))
        let longTooSoon = long.consumeIfExpired()
        #expect(!longTooSoon)
        clock.advance(by: .milliseconds(1))
        let longExpired = long.consumeIfExpired()
        #expect(longExpired)
    }
}

/// The lock protects the only mutable value shared by clock copies.
private final class ManualClock: Clock, @unchecked Sendable {
    typealias Instant = ContinuousClock.Instant
    typealias Duration = Swift.Duration
    private let lock = NSLock()
    private var instant = ContinuousClock().now
    var now: Instant {
        lock.withLock { instant }
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    func advance(by duration: Duration) {
        lock.withLock { instant = instant.advanced(by: duration) }
    }

    func sleep(until _: Instant, tolerance _: Duration?) async throws {
        preconditionFailure("This clock supports deterministic deadline checks only")
    }
}
