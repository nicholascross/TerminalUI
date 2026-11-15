import TerminalUIEngine
import Testing

struct InputDispatchTests {
    @Test func `tab reports move focus forward and backward`() {
        var reports: [(String, KeyEvent)] = [("\t", .tab), ("\u{1b}[Z", .backTab)]
        for modifiers in [1, 65, 129, 193, 2, 66, 130, 194] {
            let key: KeyEvent = modifiers.isMultiple(of: 2) ? .backTab : .tab
            reports.append(("\u{1b}[9;\(modifiers)u", key))
            reports.append(("\u{1b}[27;\(modifiers);9~", key))
        }
        let view = Element.column(spacing: 0, [
            .button("First", id: "first"),
            .button("Second", id: "second"),
            .button("Third", id: "third"),
        ])
        for (report, expected) in reports {
            let bytes = Array(report.utf8)
            for split in 0 ... bytes.count {
                var decoder = InputDecoder()
                let keys = decoder.feed(bytes.prefix(split)) + decoder.feed(bytes.dropFirst(split))
                #expect(keys == [expected])
                let engine = UIEngine()
                _ = engine.render(view, width: 30, height: 4)
                for key in keys {
                    _ = engine.handle(key, in: view)
                }
                #expect(engine.focusedID == (expected == .tab ? "second" : "third"))
                for key in keys {
                    _ = engine.handle(key, in: view)
                }
                #expect(engine.focusedID == (expected == .tab ? "third" : "second"))
            }
        }
        var decoder = InputDecoder()
        #expect(decoder.feed("\u{1b}[9;5u\u{1b}[27;3;9~".utf8).isEmpty)
    }
}
