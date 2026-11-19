import TerminalUICore
import TerminalUIInput
import Testing

struct MouseDecoderTests {
    @Test func `mouse reports preserve coordinates modifiers and input ordering across every split`() {
        let reports: [(String, MouseEvent)] = [
            ("0;1;1M", .init(.press, column: 0, row: 0)),
            ("0;2;3m", .init(.release, column: 1, row: 2)),
            ("32;2;3M", .init(.drag, column: 1, row: 2)),
            ("46;4;5M", .init(.drag, column: 3, row: 4, button: .secondary, shift: true, alt: true)),
            ("1;400;300M", .init(.press, column: 399, row: 299, button: .middle)),
            ("2;7;8m", .init(.release, column: 6, row: 7, button: .secondary)),
            ("28;2;3M", .init(.press, column: 1, row: 2, shift: true, alt: true, control: true)),
            ("64;4;5M", .init(.scrollUp, column: 3, row: 4)),
            ("81;4;5M", .init(.scrollDown, column: 3, row: 4, control: true)),
        ]
        for (report, expected) in reports {
            let bytes = Array("a\u{1b}[<\(report)\t".utf8)
            for split in 0 ... bytes.count {
                var decoder = InputDecoder()
                let events = decoder.feedEvents(bytes.prefix(split)) + decoder.feedEvents(bytes.dropFirst(split))
                #expect(events == [.key(.character("a")), .mouse(expected), .key(.tab)])
            }
        }
    }

    @Test func `invalid and unsupported mouse reports are discarded without producing keys`() {
        let invalid = [
            "0;0;1M", "0;1;0M", "0;-1;1M", "0;;1M", "0;1;1;1M", "0;1M",
            "999999999999999999999999;1;1M", "0;999999999999999999999999;1M",
            "32;1;1m", "35;1;1M", "66;1;1M", "67;1;1M", "128;1;1M", "64;1;1m", "65;1;1m",
            "0;" + String(repeating: "0", count: 130) + "1;1M",
        ]
        for report in invalid {
            var decoder = InputDecoder()
            #expect(decoder.feedEvents("\u{1b}[<\(report)q".utf8) == [.key(.character("q"))])
        }
        var decoder = InputDecoder()
        #expect(decoder.feedEvents("\u{1b}[<0;12;".utf8).isEmpty)
        #expect(decoder.flushEscape().isEmpty)
        #expect(decoder.feedEvents("q".utf8) == [.key(.character("q"))])
    }

    @Test func `mouse packets remain paste data and keyboard compatibility consumes mouse`() {
        let report = "\u{1b}[<0;1;1M"
        var decoder = InputDecoder()
        #expect(decoder.feedEvents("\u{1b}[200~\(report)\u{1b}[201~".utf8) == [.key(.paste(report))])
        #expect(decoder.feed("\(report)a\u{1b}[<0;1;1mb".utf8) == [.character("a"), .character("b")])
    }

    @Test func `legacy mouse payload cannot become an activation or text across chunks`() {
        let bytes: [UInt8] = [27, 91, 77, 65, 66, 13, 113]
        for split in 0 ... bytes.count {
            var decoder = InputDecoder()
            #expect(decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split)) == [.character("q")])
        }
    }

    @Test func `oversized unterminated mouse sequence is bounded and recovers`() {
        var decoder = InputDecoder()
        #expect(decoder.feedEvents(("\u{1b}[<0;" + String(repeating: "9", count: 256)).utf8).isEmpty)
        #expect(decoder.feedEvents(";1Mq".utf8) == [.key(.character("q"))])
    }
}
