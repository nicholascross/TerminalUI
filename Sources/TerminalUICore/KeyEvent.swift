public enum KeyEvent: Equatable, Sendable {
    case tab, backTab, enter, shiftEnter, escape, up, down, left, right, backspace, controlC, controlD, controlP
    case delete, home, end, pageUp, pageDown, shiftLeft, shiftRight, shiftUp, shiftDown
    case character(Character), paste(String)
    /// Modified printable ASCII keys. Control-C/D/P retain their dedicated cases.
    case altCharacter(Character), controlCharacter(Character)
}
