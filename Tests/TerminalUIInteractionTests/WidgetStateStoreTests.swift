@testable import TerminalUIInteraction
import Testing

struct WidgetStateStoreTests {
    @Test func `reset clears all control kinds while preserving unrelated state`() {
        let states = WidgetStateStore()
        for prefix in ["field:", "editor:", "list:", "table:", "scroll:"] {
            states[prefix + "shared"].editor.caret = 3
            states[prefix + "shared"].viewport.offset = 4
        }
        states["editor:other"].editor.selection = 2
        states.reset(id: "shared")
        for prefix in ["field:", "editor:", "list:", "table:", "scroll:"] {
            #expect(states[prefix + "shared"] == WidgetState())
        }
        #expect(states["editor:other"].editor.selection == 2)
    }

    @Test func `inactive eviction preserves active records and recent editor and viewport state`() {
        let states = WidgetStateStore(inactiveLimit: 1)
        states["editor:active"].editor.caret = 1
        states["editor:old"].editor.caret = 2
        states["editor:old"].viewport.offset = 3
        states.evictInactive(excluding: ["editor:active"])
        states["scroll:recent"].viewport.offset = 4
        states.evictInactive(excluding: ["editor:active"])
        #expect(states["editor:old"] == WidgetState())
        #expect(states["editor:active"].editor.caret == 1)
        #expect(states["scroll:recent"].viewport.offset == 4)
        states.evictInactive(excluding: ["scroll:recent"])
        #expect(states["editor:active"].editor.caret == 1)
    }
}
