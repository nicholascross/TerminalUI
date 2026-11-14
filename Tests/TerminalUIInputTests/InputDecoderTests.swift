import TerminalUICore
import TerminalUIInput
import Testing

struct InputDecoderTests {
    @Test func splitKeysAndUnicodeAreDecoded() {
        let cases: [(String, [KeyEvent])] = [
            ("\u{1b}[13;2u", [.shiftEnter]), ("\u{1b}[27;2;13~", [.shiftEnter]),
            ("\u{1b}[99;5u", [.controlC]), ("\u{1b}[100;5u", [.controlD]),
            ("\u{1b}[27;5;99~", [.controlC]), ("\u{1b}[27;5;100~", [.controlD]),
            ("\u{1b}[112;5u", [.controlP]), ("\u{1b}[27;5;112~", [.controlP]), ("\u{10}", [.controlP]),
            ("\u{1b}[13u", [.enter]), ("\u{1b}[27u", [.escape]), ("\u{1b}[A", [.up]), ("\u{1b}OD", [.left]), ("é", [.character("é")])
        ]
        for (input, expected) in cases {
            let bytes = Array(input.utf8)
            for split in 0...bytes.count {
                var decoder = InputDecoder()
                let result = decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split))
                #expect(result == expected)
            }
        }
    }

    @Test func pasteIsOneEventAcrossEverySplitAndIsBounded() {
        let bytes = Array("\u{1b}[200~abc\nxyz\u{1b}[201~".utf8)
        for split in 0...bytes.count {
            var decoder = InputDecoder(pasteLimit: 4)
            let result = decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split))
            #expect(result == [.paste("abc\n")])
            #expect(decoder.pasteWasTruncated)
        }
    }

    @Test func unknownSequencesCannotBecomeActivationAndEscapeTimesOut() {
        var decoder = InputDecoder()
        #expect(decoder.feed(Array("\u{1b}[999~".utf8)).isEmpty)
        #expect(decoder.feed([27]).isEmpty)
        #expect(decoder.flushEscape() == [.escape])
        #expect(decoder.flushEscape().isEmpty)
        #expect(decoder.feed(Array("\u{1b}[".utf8)).isEmpty)
        #expect(decoder.flushEscape().isEmpty)
    }
    @Test func malformedUTF8DoesNotSwallowFollowingKey() {
        var decoder = InputDecoder()
        #expect(decoder.feed([0xff, 0x61]) == [.character("a")])
    }

    @Test func cursorKeysWorkWithKeyboardLockModifiers() {
        for modifiers in [1, 65, 129, 193, 2, 66, 130, 194] {
            let keys: [(String, KeyEvent)] = modifiers.isMultiple(of: 2)
                ? [("A", .shiftUp), ("B", .shiftDown), ("C", .shiftRight), ("D", .shiftLeft)]
                : [("A", .up), ("B", .down), ("C", .right), ("D", .left)]
            for (suffix, key) in keys {
                let bytes = Array("\u{1b}[1;\(modifiers)\(suffix)".utf8)
                for split in 0...bytes.count {
                    var decoder = InputDecoder()
                    #expect(decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split)) == [key])
                }
            }
        }
        var decoder = InputDecoder()
        #expect(decoder.feed("\u{1b}[1;5B".utf8).isEmpty)
    }

    @Test func controlKeysWorkWithKeyboardLockModifiers() {
        for modifiers in [5, 69, 133, 197] {
            for (code, key): (Int, KeyEvent) in [(99, .controlC), (100, .controlD), (112, .controlP)] {
                let bytes = Array("\u{1b}[\(code);\(modifiers)u".utf8)
                for split in 0...bytes.count {
                    var decoder = InputDecoder()
                    #expect(decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split)) == [key])
                }
            }
        }
        var decoder = InputDecoder()
        #expect(decoder.feed("\u{1b}[99;7u".utf8).isEmpty)
    }

    @Test func controlStringsNeverGenerateKeysAcrossChunks() {
        for sequence in ["\u{1b}]52;c;payload\u{7}", "\u{1b}Pignored\u{1b}\\"] {
            let bytes = Array(sequence.utf8)
            for split in 0...bytes.count {
                var decoder = InputDecoder()
                let events = decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split))
                #expect(events.isEmpty)
                #expect(decoder.feed([3, 4]) == [.controlC, .controlD])
            }
        }
    }

    @Test func countsMultipleTruncatedPastesInOneChunk() {
        var decoder = InputDecoder(pasteLimit: 1)
        let input = "\u{1b}[200~ab\u{1b}[201~\u{1b}[200~cd\u{1b}[201~"
        #expect(decoder.feed(input.utf8) == [.paste("a"), .paste("c")])
        #expect(decoder.completedTruncatedPastes == 2)
    }

}
