import TerminalUICore

/// The presentation adapter supplies services without coupling mounted components to a terminal host.
@MainActor
package protocol ApplicationServices: AnyObject {
    func focusTarget(path: [AnyHashable], id: String) -> ScopedFocusTarget?
    func focus(_ target: ScopedFocusTarget) -> Bool
    func keepVisible(_ target: ScopedFocusTarget)
    func scope(id: AnyHashable, in parent: ViewScope?) -> ViewScope?
    func focusTarget(path: [AnyHashable], id: String, in scope: ViewScope?) -> ScopedFocusTarget?
    func reveal(id: AnyHashable, in scope: ViewScope?) -> Bool
    func stop()
}
