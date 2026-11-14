/// Tracks the idle deadline independently of terminal I/O and event dispatch.
struct EscapeDeadline<C: Clock> where C.Duration == Duration {
    private let clock: C
    private let delay: Duration
    private var pendingSince: C.Instant?
    let pollTimeout: Int32

    init(clock: C, milliseconds: Int) {
        self.clock = clock
        let milliseconds = max(1, min(5000, milliseconds))
        delay = .milliseconds(milliseconds)
        pollTimeout = Int32(min(30, milliseconds))
    }

    mutating func receivedInput() {
        pendingSince = clock.now
    }

    mutating func consumeIfExpired() -> Bool {
        guard let since = pendingSince, since.duration(to: clock.now) >= delay else { return false }
        pendingSince = nil
        return true
    }
}
