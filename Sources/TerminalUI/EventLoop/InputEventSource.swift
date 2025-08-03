import Foundation

/// Protocol defining an asynchronous source of input events for UIEventLoop.
public protocol InputEventSource {
    /// Async sequence of InputEvent values, ending on EOF or error.
    func events() -> AsyncThrowingStream<InputEvent, Error>
}
