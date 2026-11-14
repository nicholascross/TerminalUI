import Foundation
import TerminalUICore
import TerminalUIText

/// Edits application-owned text and retains only caret/selection state.
package struct EditorInteraction {
    let states: WidgetStateStore
    let coordinates: EditorCoordinates

    package init(states: WidgetStateStore, coordinates: EditorCoordinates) {
        self.states = states
        self.coordinates = coordinates
    }

    package func handle(_ key: KeyEvent, id: String, value: String, multiline: Bool) -> UIEventResult {
        let stateID = (multiline ? "editor:" : "field:") + id
        switch key {
        case .altCharacter, .controlCharacter: return .rebuild(action: .unhandledKey(key))
        default: break
        }
        var chars = Array(value)
        var position = min(states[stateID].editor.caret ?? chars.count, chars.count)
        let anchor = min(states[stateID].editor.selection ?? position, chars.count)
        let selected = min(anchor, position) ..< max(anchor, position)
        let hadSelection = !selected.isEmpty
        switch key {
        case .up, .down, .shiftUp, .shiftDown: break
        default: states[stateID].editor.preferredColumn = nil
        }
        switch key {
        case .shiftUp where multiline, .shiftDown where multiline:
            if states[stateID].editor.selection == nil { states[stateID].editor.selection = position }
        case .shiftLeft, .shiftRight:
            if states[stateID].editor.selection == nil { states[stateID].editor.selection = position }
            position = key == .shiftLeft ? max(0, position - 1) : min(chars.count, position + 1)
            states[stateID].editor.caret = position
            return .rebuild(action: nil)
        case .character, .paste, .delete, .backspace, .enter, .shiftEnter:
            if key == .enter || key == .shiftEnter, !multiline { break }
            if hadSelection {
                chars.removeSubrange(selected)
                position = selected.lowerBound
            }
            states[stateID].editor.selection = nil
            if hadSelection, key == .delete || key == .backspace {
                states[stateID].editor.caret = position
                return .rebuild(action: .textChanged(id, String(chars)))
            }
        default: states[stateID].editor.selection = nil
        }
        switch key {
        case .left: position = hadSelection ? selected.lowerBound : max(0, position - 1)
        case .right: position = hadSelection ? selected.upperBound : min(chars.count, position + 1)
        case .home:
            while position > 0, chars[position - 1] != "\n" {
                position -= 1
            }
        case .end:
            while position < chars.count, chars[position] != "\n" {
                position += 1
            }
        case .up where multiline, .down where multiline, .shiftUp where multiline, .shiftDown where multiline:
            position = verticalPosition(key, characters: chars, position: position, stateID: stateID)
        case .delete:
            if position < chars.count {
                chars.remove(at: position)
                states[stateID].editor.caret = position
                return .rebuild(action: .textChanged(id, String(chars)))
            }
        case .backspace:
            if position > 0 {
                chars.remove(at: position - 1)
                position -= 1
                states[stateID].editor.caret = position
                return .rebuild(action: .textChanged(id, String(chars)))
            }
        case let .character(char):
            guard !char.isControlCharacter else { return .rebuild(action: nil) }
            return insert(String(char), chars: chars, at: position, id: id, stateID: stateID)
        case .enter where multiline, .shiftEnter where multiline:
            chars.insert("\n", at: position)
            position += 1
            states[stateID].editor.caret = position
            return .rebuild(action: .textChanged(id, String(chars)))
        case let .paste(text):
            let inserted = pasteCharacters(text, multiline: multiline)
            return insert(String(inserted), chars: chars, at: position, id: id, stateID: stateID)
        default: return .rebuild(action: .unhandledKey(key))
        }
        states[stateID].editor.caret = position
        return .rebuild(action: nil)
    }

    private func insert(_ text: String, chars: [Character], at position: Int, id: String, stateID: String) -> UIEventResult {
        let prefix = String(chars.prefix(position)) + text
        let result = prefix + String(chars.dropFirst(position))
        states[stateID].editor.caret = prefix.count
        return .rebuild(action: .textChanged(id, result))
    }

    private func verticalPosition(_ key: KeyEvent, characters chars: [Character], position: Int, stateID: String) -> Int {
        let width = max(1, states[stateID].viewport.width ?? 4096)
        let coordinates = coordinates.positions(chars, width: width, multiline: true)
        let current = coordinates[position]
        let desiredColumn = states[stateID].editor.preferredColumn ?? current.column
        states[stateID].editor.preferredColumn = desiredColumn
        let movesUp = key == .up || key == .shiftUp
        let targetRow = current.row + (movesUp ? -1 : 1)
        let candidates = coordinates.indices.filter { coordinates[$0].row == targetRow }
        return candidates.min(by: {
            abs(coordinates[$0].column - desiredColumn) < abs(coordinates[$1].column - desiredColumn)
        }) ?? position
    }

    private func pasteCharacters(_ text: String, multiline: Bool) -> [Character] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let safe = normalized.filter { $0 == "\n" || !$0.isControlCharacter }
        return Array(multiline ? safe : safe.replacingOccurrences(of: "\n", with: " "))
    }
}

private extension Character {
    var isControlCharacter: Bool {
        unicodeScalars.contains { $0.value < 32 || (0x7F ... 0x9F).contains($0.value) }
    }
}
