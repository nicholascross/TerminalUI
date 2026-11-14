import TerminalUI
import Testing

struct ModifiedKeyTests {
    @Test func numericModifiersDecodeAcrossEverySplit() {
        for digit in "0123456789" {
            let code = digit.asciiValue!
            var cases: [(String, KeyEvent)] = [("\u{1b}\(digit)", .altCharacter(digit))]
            for locks in [0, 64, 128, 192] {
                for (modifier, key): (Int, KeyEvent) in [(3, .altCharacter(digit)), (5, .controlCharacter(digit))] {
                    cases += [("\u{1b}[\(code);\(modifier + locks)u", key), ("\u{1b}[27;\(modifier + locks);\(code)~", key)]
                }
            }
            for (input, expected) in cases {
                let bytes = Array(input.utf8)
                for split in 0...bytes.count {
                    var decoder = InputDecoder()
                    #expect(decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split)) == [expected])
                }
            }
        }
    }

    @Test func escapeTimeoutAndPasteDoNotBecomeModifiedKeys() {
        var decoder = InputDecoder()
        #expect(decoder.feed([27]).isEmpty)
        #expect(decoder.flushEscape() == [.escape])
        #expect(decoder.feed("3".utf8) == [.character("3")])
        let paste = "\u{1b}[200~\u{1b}3\u{1b}[49;3u\u{1b}[201~"
        let bytes = Array(paste.utf8)
        for split in 0...bytes.count {
            var pasted = InputDecoder()
            #expect(pasted.feed(bytes.prefix(split)) + pasted.feed(bytes.dropFirst(split)) == [.paste("\u{1b}3\u{1b}[49;3u")])
        }
        for invalid in ["\u{1b}[49;0u", "\u{1b}[49;7u", "\u{1b}[49;2u", "\u{1b}[10;3u", "\u{1b}[27;5;99999999~"] {
            #expect(decoder.feed(invalid.utf8).isEmpty)
        }
    }

    @Test func focusedKeyBindingDistinguishesTypingFromPasteAndRespectsDialog() {
        let engine = UIEngine()
        let field = Element.textField(id: "search", value: "").onKey(.character("3"), activate: "activity")
        #expect(engine.handle(.character("3"), in: field) == .activated("activity"))
        #expect(engine.handle(.paste("3"), in: field) == .textChanged("search", "3"))
        #expect(engine.handle(.character("3"), in: field.enabled(false)) == .unhandledKey(.character("3")))
        let dialog = field.overlay(.dialog(id: "modal", title: "Modal", content: .textField(id: "inside", value: "")))
        #expect(engine.handle(.character("3"), in: dialog) == .textChanged("inside", "3"))
    }

    @Test func modifiedKeysPreserveEditorSelectionAndCaret() {
        let engine = UIEngine()
        let editor = Element.textEditor(id: "editor", value: "draft")
        _ = engine.handle(.shiftLeft, in: editor)
        for key: KeyEvent in [.altCharacter("0"), .controlCharacter("3")] {
            #expect(engine.handle(key, in: editor) == .unhandledKey(key))
        }
        #expect(engine.handle(.character("!"), in: editor) == .textChanged("editor", "draf!"))
    }
}
