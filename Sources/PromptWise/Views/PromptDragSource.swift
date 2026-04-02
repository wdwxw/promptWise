import AppKit
import SwiftUI

// MARK: - Drag Handle for List View

struct PromptDragHandle: NSViewRepresentable {
    let prompt: Prompt
    let onDragStarted: (Prompt) -> Void
    let onDragEnded: () -> Void
    var onExternalDrop: ((Prompt) -> Void)? = nil

    func makeNSView(context: Context) -> PromptDragHandleView {
        let view = PromptDragHandleView()
        view.configure(prompt: prompt, onDragStarted: onDragStarted, onDragEnded: onDragEnded, onExternalDrop: onExternalDrop)
        return view
    }

    func updateNSView(_ nsView: PromptDragHandleView, context: Context) {
        nsView.configure(prompt: prompt, onDragStarted: onDragStarted, onDragEnded: onDragEnded, onExternalDrop: onExternalDrop)
    }
}

final class PromptDragHandleView: NSView, NSDraggingSource {
    private var promptContent: String = ""
    private var promptTitle: String = ""
    private var onDragStarted: (() -> Void)?
    private var onDragEnded: (() -> Void)?
    private var onExternalDrop: (() -> Void)?
    private var mouseDownPoint: NSPoint = .zero
    private var hasDragStarted = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    func configure(
        prompt: Prompt,
        onDragStarted: @escaping (Prompt) -> Void,
        onDragEnded: @escaping () -> Void,
        onExternalDrop: ((Prompt) -> Void)? = nil
    ) {
        self.promptContent = prompt.content
        self.promptTitle = prompt.title
        self.onDragStarted = { onDragStarted(prompt) }
        self.onDragEnded = onDragEnded
        self.onExternalDrop = onExternalDrop.map { handler in { handler(prompt) } }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = NSImage(
            systemSymbolName: "line.3.horizontal",
            accessibilityDescription: "拖拽排序"
        ) else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        let configured = image.withSymbolConfiguration(config) ?? image
        let imageSize = configured.size

        configured.isTemplate = true
        NSColor.tertiaryLabelColor.set()
        configured.draw(
            in: NSRect(
                x: (bounds.width - imageSize.width) / 2,
                y: (bounds.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        hasDragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasDragStarted else { return }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - mouseDownPoint.x
        let dy = current.y - mouseDownPoint.y
        guard sqrt(dx * dx + dy * dy) > 3 else { return }

        hasDragStarted = true
        onDragStarted?()

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(promptContent, forType: .string)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: makeDragImage())

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        hasDragStarted = false
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : .move
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if operation == .copy {
            onExternalDrop?()
        }
        onDragEnded?()
    }

    private func makeDragImage() -> NSImage {
        let text = promptTitle as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: attrs)
        let padding: CGFloat = 12
        let size = NSSize(width: textSize.width + padding * 2, height: textSize.height + padding)

        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.withAlphaComponent(0.95).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        text.draw(at: NSPoint(x: padding, y: padding / 2), withAttributes: attrs)
        image.unlockFocus()

        return image
    }
}

// MARK: - Draggable Wrapper for Grid Items

struct DraggablePromptOverlay: NSViewRepresentable {
    let prompt: Prompt
    let onDragStarted: (Prompt) -> Void
    let onDragEnded: () -> Void
    let onTap: () -> Void
    var onExternalDrop: ((Prompt) -> Void)? = nil

    func makeNSView(context: Context) -> DraggablePromptOverlayView {
        let view = DraggablePromptOverlayView()
        view.configure(prompt: prompt, onDragStarted: onDragStarted, onDragEnded: onDragEnded, onTap: onTap, onExternalDrop: onExternalDrop)
        return view
    }

    func updateNSView(_ nsView: DraggablePromptOverlayView, context: Context) {
        nsView.configure(prompt: prompt, onDragStarted: onDragStarted, onDragEnded: onDragEnded, onTap: onTap, onExternalDrop: onExternalDrop)
    }
}

final class DraggablePromptOverlayView: NSView, NSDraggingSource {
    private var promptContent: String = ""
    private var promptTitle: String = ""
    private var onDragStarted: (() -> Void)?
    private var onDragEnded: (() -> Void)?
    private var onExternalDrop: (() -> Void)?
    private var onTap: (() -> Void)?
    private var mouseDownPoint: NSPoint = .zero
    private var hasDragStarted = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    func configure(
        prompt: Prompt,
        onDragStarted: @escaping (Prompt) -> Void,
        onDragEnded: @escaping () -> Void,
        onTap: @escaping () -> Void,
        onExternalDrop: ((Prompt) -> Void)? = nil
    ) {
        self.promptContent = prompt.content
        self.promptTitle = prompt.title
        self.onDragStarted = { onDragStarted(prompt) }
        self.onDragEnded = onDragEnded
        self.onExternalDrop = onExternalDrop.map { handler in { handler(prompt) } }
        self.onTap = onTap
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        hasDragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasDragStarted else { return }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - mouseDownPoint.x
        let dy = current.y - mouseDownPoint.y
        guard sqrt(dx * dx + dy * dy) > 3 else { return }

        hasDragStarted = true
        onDragStarted?()

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(promptContent, forType: .string)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: makeDragImage())

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !hasDragStarted {
            onTap?()
        }
        hasDragStarted = false
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : .move
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if operation == .copy {
            onExternalDrop?()
        }
        onDragEnded?()
    }

    private func makeDragImage() -> NSImage {
        let text = promptTitle as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: attrs)
        let padding: CGFloat = 12
        let size = NSSize(width: textSize.width + padding * 2, height: textSize.height + padding)

        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.withAlphaComponent(0.95).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        text.draw(at: NSPoint(x: padding, y: padding / 2), withAttributes: attrs)
        image.unlockFocus()

        return image
    }
}
