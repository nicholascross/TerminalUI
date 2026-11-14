import TerminalUICore
import TerminalUIText

package struct LayoutAllocator {
    let measurement: LayoutMeasurer
    let metrics: TextMetrics

    package init(measurement: LayoutMeasurer, metrics: TextMetrics) {
        self.measurement = measurement
        self.metrics = metrics
    }

    package func allocate(_ children: [LayoutNode], length: Int, width: Int, vertical: Bool, theme: Theme) -> [Int] {
        var remaining = length
        var sizes = Array(repeating: 0, count: children.count)
        var flexible: [(Int, Int)] = []
        var fitted: [Int] = []
        for (index, child) in children.enumerated() {
            let rule = vertical ? child.element.heightRule : child.element.widthRule
            switch rule {
            case let .fill(weight): flexible.append((index, max(1, min(weight, 4096))))
            case let .fixed(value): sizes[index] = min(remaining, max(0, value)); remaining -= sizes[index]
            case .fit: fitted.append(index)
            case .content:
                let measured = measurement.measure(child, width: width, theme: theme)
                sizes[index] = min(remaining, vertical ? measured.1 : measured.0)
                remaining -= sizes[index]
            }
        }
        for index in fitted {
            let measured = measurement.measure(children[index], width: width, theme: theme)
            sizes[index] = min(remaining, vertical ? measured.1 : measured.0)
            remaining -= sizes[index]
        }
        var weightLeft = flexible.reduce(0) { $0 + $1.1 }
        for (index, weight) in flexible {
            let size = weightLeft > 0 ? remaining * weight / weightLeft : 0
            sizes[index] = size; remaining -= size; weightLeft -= weight
        }
        return sizes
    }

    package func tableWidths(_ columns: [TableColumn], available: Int) -> [Int] {
        var remaining = max(0, available - min(available, max(0, columns.count - 1)))
        var widths = Array(repeating: 0, count: columns.count)
        var flexible: [(Int, Int)] = []
        for (index, column) in columns.enumerated() {
            switch column.width {
            case let .fixed(value):
                widths[index] = min(remaining, max(0, value)); remaining -= widths[index]
            case .content:
                widths[index] = min(remaining, metrics.cellLength(column.title)); remaining -= widths[index]
            case let .fit(maximum):
                widths[index] = min(remaining, max(0, min(maximum, metrics.cellLength(column.title)))); remaining -= widths[index]
            case let .fill(weight): flexible.append((index, max(1, min(4096, weight))))
            }
        }
        var total = flexible.reduce(0) { $0 + $1.1 }
        for (index, weight) in flexible {
            let width = remaining * weight / total
            widths[index] = width; remaining -= width; total -= weight
        }
        return widths
    }

    package func alignedOffset(_ remaining: Int, _ alignment: Alignment?) -> Int {
        switch alignment {
        case .center: max(0, remaining) / 2
        case .trailing: max(0, remaining)
        default: 0
        }
    }
}
