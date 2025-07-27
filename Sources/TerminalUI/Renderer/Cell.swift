import Foundation

/// A styled cell in the screen buffer.
public struct Cell: Equatable {
    public let char: Character
    public let style: Style
}
