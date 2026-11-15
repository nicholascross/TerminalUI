import TerminalUICore
import TerminalUIRendering

/// Commits a frame only after the injected transport accepts the complete output.
struct TerminalFrameWriter {
    private var encoder: FrameEncoder
    private let write: @Sendable ([UInt8]) async throws -> Void

    init(encoder: FrameEncoder, write: @escaping @Sendable ([UInt8]) async throws -> Void) {
        self.encoder = encoder
        self.write = write
    }

    mutating func writeFrame(_ frame: CellGrid) async throws {
        let bytes = Array(encoder.prepare(frame).utf8)
        do {
            try await write(bytes)
            encoder.commit()
        } catch {
            encoder.discard()
            throw error
        }
    }
}
