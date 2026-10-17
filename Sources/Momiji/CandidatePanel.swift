import AppKit
import MomijiCore

class ListPanel: NSPanel {
    struct Row {
        let label: Character?
        let text: String
        let isSelected: Bool
    }

    private let stack = NSStackView()
    private let fontSize: CGFloat

    init(fontSize: CGFloat) {
        self.fontSize = fontSize
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        background.layer?.masksToBounds = true
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        contentView = background
    }

    func show(rows: [Row], footer: String?, below caret: NSRect) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for row in rows {
            let view = makeRow(row)
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        if let footer {
            let label = NSTextField(labelWithString: footer)
            label.font = .systemFont(ofSize: fontSize * 0.75)
            label.textColor = .secondaryLabelColor
            label.alignment = .right
            let container = NSStackView(views: [label])
            container.edgeInsets = NSEdgeInsets(top: 2, left: 10, bottom: 0, right: 10)
            stack.addArrangedSubview(container)
            container.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        stack.layoutSubtreeIfNeeded()
        let size = NSSize(width: max(stack.fittingSize.width, 160), height: stack.fittingSize.height)
        setFrame(Self.frame(size: size, below: caret), display: true)
        orderFrontRegardless()
    }

    private func makeRow(_ row: Row) -> NSView {
        var views: [NSView] = []
        if let label = row.label {
            let key = NSTextField(labelWithString: String(label))
            key.font = .monospacedSystemFont(ofSize: fontSize * 0.85, weight: .bold)
            key.textColor = row.isSelected ? .selectedMenuItemTextColor : .controlAccentColor
            key.alignment = .center
            key.widthAnchor.constraint(equalToConstant: fontSize).isActive = true
            views.append(key)
        }
        let text = NSTextField(labelWithString: row.text)
        text.font = .systemFont(ofSize: fontSize)
        text.textColor = row.isSelected ? .selectedMenuItemTextColor : .labelColor
        views.append(text)
        let container = NSStackView(views: views)
        container.spacing = 8
        container.edgeInsets = NSEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        container.wantsLayer = true
        container.layer?.backgroundColor = row.isSelected ? NSColor.selectedContentBackgroundColor.cgColor : nil
        return container
    }

    private static func frame(size: NSSize, below caret: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(caret) || $0.frame.contains(caret.origin) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var origin = NSPoint(x: caret.minX, y: caret.minY - size.height - 4)
        if origin.y < visible.minY {
            origin.y = caret.maxY + 4
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        return NSRect(origin: origin, size: size)
    }
}

final class CandidatePanel: ListPanel {
    init() { super.init(fontSize: 15) }

    func update(_ model: CandidateWindowModel?, caret: NSRect) {
        guard let model else {
            orderOut(nil)
            return
        }
        let rows = model.candidates.enumerated().map { index, text in
            Row(label: model.labels[index], text: text, isSelected: index == model.selectedIndex)
        }
        show(rows: rows, footer: "\(model.page) / \(model.pageCount)", below: caret)
    }
}
