public enum KeyEvent: Equatable, Sendable {
    case tab, backTab, enter, shiftEnter, escape, up, down, left, right, backspace, controlC, controlD, controlP
    case delete, home, end, pageUp, pageDown, shiftLeft, shiftRight, shiftUp, shiftDown
    case character(Character), paste(String)
    /// Modified printable ASCII keys. Control-C/D/P retain their dedicated cases.
    case altCharacter(Character), controlCharacter(Character)
}

extension KeyEvent {
    /// The modified keys accepted by both shortcut declarations and routing.
    package var globalShortcut: KeyEvent? {
        switch self {
        case .controlC, .controlD, .controlP: return self
        case .altCharacter(let character), .controlCharacter(let character):
            guard let ascii = character.asciiValue, (32...126).contains(ascii) else { return nil }
            if case .controlCharacter = self {
                switch character {
                case "c": return .controlC
                case "d": return .controlD
                case "p": return .controlP
                default: break
                }
            }
            return self
        default: return nil
        }
    }

    package func validatedGlobalShortcut() -> KeyEvent {
        guard let key = globalShortcut else {
            preconditionFailure(
                "Unsupported global keyboard shortcut: \(self). Use .altCharacter or .controlCharacter with printable ASCII (space through ~), or .controlC, .controlD, .controlP."
            )
        }
        return key
    }
}
