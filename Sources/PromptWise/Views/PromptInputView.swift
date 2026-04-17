import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let appendToPromptInput = Notification.Name("com.promptwise.appendToPromptInput")
    static let doAppendToPromptInput = Notification.Name("com.promptwise.doAppendToPromptInput")
    static let promptInputDidCopy = Notification.Name("com.promptwise.promptInputDidCopy")
}

final class PromptInputTextView: NSTextView {
    override func copy(_ sender: Any?) {
        if selectedRange().length > 0 {
            super.copy(sender)
            NotificationCenter.default.post(name: .promptInputDidCopy, object: nil)
            return
        }

        let content = string
        guard !content.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        NotificationCenter.default.post(name: .promptInputDidCopy, object: nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "c" {
            copy(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct PromptInputView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var text: String = ""
    @State private var isCopied = false
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("提示语输入")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(theme.border)
            
            // 文本编辑区
            PromptInputTextEditor(
                text: $text,
                selectedRange: $selectedRange,
                mode: theme.mode
            )
            .frame(minHeight: 200)
            .padding(12)
            
            Divider()
                .background(theme.border)
            
            // 底部工具栏
            HStack {
                Spacer()
                
                Button {
                    copyToClipboard()
                } label: {
                    Text(isCopied ? "已复制" : "复制")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 320)
        .background(theme.panelBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.border, lineWidth: 1)
        )
        .onAppear {
            text = ThemeManager.shared.promptInputDraft
        }
        .onDisappear {
            ThemeManager.shared.promptInputDraft = text
        }
        .onDrop(of: [UTType.text, UTType.plainText, UTType.utf8PlainText], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: .doAppendToPromptInput)) { notification in
            if let content = notification.userInfo?["content"] as? String {
                appendContent(content)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptInputDidCopy)) { _ in
            showCopiedFeedback()
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopiedFeedback()
    }

    private func showCopiedFeedback() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { (string, error) in
                    if let content = string as? String {
                        DispatchQueue.main.async {
                            appendContent(content)
                        }
                    }
                }
                break
            }
        }
    }
    
    /// 在光标位置追加内容（前置换行符）
    func appendContent(_ content: String) {
        let insertText = text.isEmpty ? content : "\n" + content
        let location = min(selectedRange.location, text.count)
        
        let index = text.index(text.startIndex, offsetBy: location)
        text.insert(contentsOf: insertText, at: index)
        selectedRange = NSRange(location: location + insertText.count, length: 0)
    }
}

// MARK: - 自定义 TextEditor（支持拖拽接收 + 光标位置追踪）

struct PromptInputTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    let mode: ThemeMode
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = PromptInputTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 0)
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true

        // 注册拖拽类型
        textView.registerForDraggedTypes([.string])

        applyTheme(to: scrollView, textView: textView, mode: mode)

        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // 更新主题颜色与滚动条样式
        applyTheme(to: nsView, textView: textView, mode: mode)

        if textView.string != text {
            let currentSelection = textView.selectedRange()
            textView.string = text
            let newLocation = min(currentSelection.location, text.count)
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
        }
    }

    private func applyTheme(to scrollView: NSScrollView, textView: NSTextView, mode: ThemeMode) {
        let isDark = mode == .dark
        let surface = isDark
            ? NSColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1)
            : NSColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        let textPrimary = isDark
            ? NSColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            : NSColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        let accent = NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1)

        textView.textColor = textPrimary
        textView.backgroundColor = surface
        textView.insertionPointColor = accent
        textView.drawsBackground = true

        // 使用 overlay 滚动条，避免无滚动内容时占用右侧槽位
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = surface
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.appearance = nil
        scrollView.borderType = .noBorder
        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = surface
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectedRange: Binding<NSRange>
        
        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            self.text = text
            self.selectedRange = selectedRange
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            selectedRange.wrappedValue = textView.selectedRange()
        }
    }
}
