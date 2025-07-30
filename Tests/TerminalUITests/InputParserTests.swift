import Foundation
import Testing
@testable import TerminalUI

@Suite("InputParser")
struct InputParserTests {
    func feed(_ bytes: [UInt8]) -> [InputEvent] {
        var parser = InputParser()
        var out: [InputEvent] = []
        for byte in bytes {
            if let event = parser.consume(byte) {
                out.append(event)
            }
        }
        if let event = parser.flushEOF() {
            out.append(event)
        }
        return out
    }

    @Test
    func printableASCII() {
        let events = feed([UInt8(ascii: "a")])
        #expect(events == [InputEvent.char("a")])
    }

    @Test
    func enterCRLF() {
        #expect(feed([13]) == [.enter])
        #expect(feed([10]) == [.enter])
    }

    @Test
    func backspaceVariants() {
        #expect(feed([127]) == [.backspace])
        #expect(feed([8]) == [.backspace])
    }

    @Test
    func tabAndPaste() {
        #expect(feed([9]) == [.tab])
        let seq: [UInt8] = [27, 91] + Array("200".utf8) + [126, 9, 27, 91] + Array("201".utf8) + [126]
        #expect(feed(seq) == [InputEvent.pasteStart, InputEvent.char("\t"), InputEvent.pasteEnd])
    }

    @Test
    func ctrlCAndSubmit() {
        #expect(feed([3]) == [.ctrlC])
        #expect(feed([4]) == [.submit])
    }

    @Test
    func csiArrows() {
        let types: [(UInt8, InputEvent)] = [
            (UInt8(ascii: "A"), .upArrow),
            (UInt8(ascii: "B"), .downArrow),
            (UInt8(ascii: "C"), .rightArrow),
            (UInt8(ascii: "D"), .leftArrow)
        ]
        for (code, expectedEvent) in types {
            let seq: [UInt8] = [27, 91, code]
            #expect(feed(seq) == [expectedEvent])
        }
    }

    @Test
    func ss3Arrows() {
        let types: [(UInt8, InputEvent)] = [
            (UInt8(ascii: "A"), .upArrow),
            (UInt8(ascii: "B"), .downArrow),
            (UInt8(ascii: "C"), .rightArrow),
            (UInt8(ascii: "D"), .leftArrow)
        ]
        for (code, expectedEvent) in types {
            let seq: [UInt8] = [27, 79, code]
            #expect(feed(seq) == [expectedEvent])
        }
    }

    @Test
    func malformedCSIWithoutFinal() {
        let seq: [UInt8] = [27, 91, 49, 49]
        #expect(feed(seq) == [.unknown])
    }

    @Test
    func csiOverflow() {
        let overflowBytes = Array(repeating: UInt8(ascii: "b"), count: maxCSILength + 1)
        let seq = [27, 91] + overflowBytes
        #expect(feed(seq) == [.unknown])
    }

    @Test
    func validUTF8() {
        let euros: [UInt8] = [0xE2, 0x82, 0xAC]
        let events = feed(euros)
        #expect(events == [InputEvent.char("€")])
    }

    @Test
    func invalidUTF8Continuation() {
        let seq: [UInt8] = [0xC2, 0x20]
        #expect(feed(seq) == [.unknown])
    }
}

// expose for tests
private let maxCSILength = 32
