import TerminalUICore

extension InputDecoder {
    static let keySequences: [([UInt8], KeyEvent)] = [
        (Array("\u{1B}[A".utf8), .up), (Array("\u{1B}[B".utf8), .down),
        (Array("\u{1B}[C".utf8), .right), (Array("\u{1B}[D".utf8), .left),
        (Array("\u{1B}[Z".utf8), .backTab),
        (Array("\u{1B}[13;2u".utf8), .shiftEnter), (Array("\u{1B}[27;2;13~".utf8), .shiftEnter),
        (Array("\u{1B}[27;5;99~".utf8), .controlC), (Array("\u{1B}[27;5;100~".utf8), .controlD),
        (Array("\u{1B}[27;5;112~".utf8), .controlP),
        (Array("\u{1B}[13u".utf8), .enter), (Array("\u{1B}[27u".utf8), .escape),
        (Array("\u{1B}[1;2D".utf8), .shiftLeft), (Array("\u{1B}[1;2C".utf8), .shiftRight),
        (Array("\u{1B}[1;2A".utf8), .shiftUp), (Array("\u{1B}[1;2B".utf8), .shiftDown),
        (Array("\u{1B}[H".utf8), .home), (Array("\u{1B}[F".utf8), .end),
        (Array("\u{1B}OH".utf8), .home), (Array("\u{1B}OF".utf8), .end),
        (Array("\u{1B}[1~".utf8), .home), (Array("\u{1B}[4~".utf8), .end),
        (Array("\u{1B}[3~".utf8), .delete), (Array("\u{1B}[5~".utf8), .pageUp),
        (Array("\u{1B}[6~".utf8), .pageDown),
        (Array("\u{1B}OA".utf8), .up), (Array("\u{1B}OB".utf8), .down),
        (Array("\u{1B}OC".utf8), .right), (Array("\u{1B}OD".utf8), .left),
    ]
}
