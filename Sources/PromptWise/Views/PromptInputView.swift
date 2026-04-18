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
    @StateObject private var sessionStore = PromptInputSessionStore.shared
    @StateObject private var configStore = AIModelConfigStore.shared
    
    @State private var text: String = ""
    @State private var isCopied = false
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isOptimizing = false
    @State private var showModelConfig = false
    @State private var currentStreamingVersionId: UUID?
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var optimizeTask: Task<Void, Never>?
    @State private var isCancelled = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 标题栏
            headerSection
            
            Divider().background(theme.border)
            
            // 2. 状态条（版本切换按钮）
            statusBarSection
            
            Divider().background(theme.border)
            
            // 3. 文本编辑区
            editorSection
            
            Divider().background(theme.border)
            
            // 4. 统计信息
            statsSection
            
            Divider().background(theme.border)
            
            // 5. 底部工具栏
            footerSection
        }
        .frame(width: 450, height: 420)
        .background(theme.panelBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.border, lineWidth: 1)
        )
        .onAppear {
            loadSession()
        }
        .onDisappear {
            saveSession()
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
        .sheet(isPresented: $showModelConfig) {
            AIModelConfigListView()
                .environmentObject(theme)
                .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
        }
        .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
    }
    
    // MARK: - 标题栏
    
    private var headerSection: some View {
        HStack {
            Text("提示语输入")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button {
                showModelConfig = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("模型设置")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 状态条
    
    private var statusBarSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "当前"按钮
                versionButton(
                    title: "当前",
                    isSelected: sessionStore.session.isOriginalSelected,
                    isLoading: false,
                    action: { selectOriginal() }
                )
                
                // 优化版本按钮 - 显示模型配置名称
                ForEach(sessionStore.session.versions) { version in
                    versionButton(
                        title: version.modelConfigName,
                        isSelected: sessionStore.session.selectedVersionId == version.id,
                        isLoading: isOptimizing && currentStreamingVersionId == version.id,
                        action: { selectVersion(version.id) }
                    )
                }
                
                Spacer(minLength: 0)
                
                // 清除按钮
                if !sessionStore.session.versions.isEmpty {
                    Button {
                        // 先停止正在进行的优化
                        if isOptimizing {
                            stopOptimize()
                        }
                        clearVersions()
                    } label: {
                        Text("清除")
                            .font(.system(size: 11))
                            .foregroundStyle(isOptimizing ? .red : theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.surfaceBg.opacity(0.5))
                    .clipShape(Capsule())
                    .help(isOptimizing ? "停止并清除所有优化版本" : "清除所有优化版本")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    private func versionButton(title: String, isSelected: Bool, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                        .tint(isSelected ? .white : theme.textSecondary)
                }
                Text(isLoading ? "生成中..." : title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? theme.accent : theme.surfaceBg)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? theme.accent : theme.border, lineWidth: isSelected ? 0 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    // MARK: - 编辑区
    
    private var editorSection: some View {
        PromptInputTextEditor(
            text: $text,
            selectedRange: $selectedRange,
            mode: theme.mode
        )
        .frame(minHeight: 180)
        .padding(12)
        .onChange(of: text) { newValue in
            // 只有在显示原始内容时，才更新原始内容
            if sessionStore.session.isOriginalSelected && currentStreamingVersionId == nil {
                sessionStore.updateOriginalContent(newValue)
            }
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }
    
    // MARK: - 统计信息
    
    private var statsSection: some View {
        HStack {
            Text("字符: \(text.count)")
            Text("|")
            Text("Token: ~\(tokenEstimate)")
            Spacer()
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(theme.textTertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var tokenEstimate: Int {
        guard !text.isEmpty else { return 0 }
        let cjkCount = text.unicodeScalars.filter {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||
            ($0.value >= 0x20000 && $0.value <= 0x2A6DF)
        }.count
        let otherCount = text.count - cjkCount
        return cjkCount + max(0, Int(ceil(Double(otherCount) / 4.0)))
    }
    
    // MARK: - 底部工具栏
    
    private var footerSection: some View {
        HStack(spacing: 12) {
            // 模型选择
            Menu {
                ForEach(configStore.configs) { config in
                    Button {
                        configStore.selectConfig(id: config.id)
                    } label: {
                        HStack {
                            Text(config.name)
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            if configStore.selectedConfigId == config.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(configStore.selectedConfig?.name ?? "选择模型")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.border, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity)
            .disabled(isOptimizing)
            
            // 优化/停止按钮
            Button {
                if isOptimizing {
                    stopOptimize()
                } else {
                    optimizeTask = Task { await startOptimize() }
                }
            } label: {
                HStack(spacing: 4) {
                    if isOptimizing {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                    }
                    Text(isOptimizing ? "停止" : "优化")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isOptimizing
                    ? Color.red.opacity(0.8)
                    : (sessionStore.session.originalContent.isEmpty || configStore.selectedConfig == nil)
                        ? theme.textTertiary
                        : theme.accent
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(!isOptimizing && (sessionStore.session.originalContent.isEmpty || configStore.selectedConfig == nil))
            
            // 复制按钮
            Button {
                copyToClipboard()
            } label: {
                Text(isCopied ? "已复制" : "复制")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.surfaceBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 会话管理
    
    private func loadSession() {
        text = sessionStore.session.currentContent
    }
    
    private func saveSession() {
        sessionStore.save()
    }
    
    private func selectOriginal() {
        // 切换版本时停止正在进行的优化
        if isOptimizing {
            stopOptimize()
        }
        sessionStore.selectVersion(nil)
        text = sessionStore.session.originalContent
    }
    
    private func selectVersion(_ id: UUID) {
        // 如果正在优化且切换到非当前流式版本，先停止
        if isOptimizing && id != currentStreamingVersionId {
            stopOptimize()
        }
        sessionStore.selectVersion(id)
        text = sessionStore.session.currentContent
    }
    
    private func clearVersions() {
        sessionStore.clearVersions()
        text = sessionStore.session.originalContent
    }
    
    private func stopOptimize() {
        AILogger.shared.log("用户停止优化")
        isCancelled = true
        optimizeTask?.cancel()
        optimizeTask = nil
        isOptimizing = false
        
        // 如果有正在生成的版本，保留已生成的内容
        if currentStreamingVersionId != nil {
            sessionStore.save()
            AILogger.shared.log("保存已生成的部分内容")
        }
        currentStreamingVersionId = nil
    }
    
    // MARK: - 优化操作
    
    private func startOptimize() async {
        guard let config = configStore.selectedConfig else {
            errorMessage = "请先选择模型"
            showErrorAlert = true
            return
        }
        
        let originalContent = sessionStore.session.originalContent
        guard !originalContent.isEmpty else {
            errorMessage = "请输入内容"
            showErrorAlert = true
            return
        }
        
        isOptimizing = true
        isCancelled = false
        errorMessage = nil
        
        AILogger.shared.log("开始优化任务")
        
        // 创建新版本（初始内容为空）
        let version = sessionStore.addVersion(
            content: "",
            modelConfigId: config.id,
            modelConfigName: config.name
        )
        currentStreamingVersionId = version.id
        text = ""
        
        do {
            if config.streamEnabled {
                // 流式输出
                var fullContent = ""
                try await AIService.shared.optimizeStream(
                    userPrompt: originalContent,
                    config: config
                ) { [self] chunk in
                    // 检查是否被取消
                    guard !isCancelled else {
                        AILogger.shared.log("流式输出已被取消，停止接收")
                        return
                    }
                    fullContent += chunk
                    text = fullContent
                    sessionStore.updateVersionContent(version.id, content: fullContent)
                }
                
                // 检查是否被取消
                if !isCancelled {
                    // 流式结束后保存
                    sessionStore.save()
                    AILogger.shared.log("流式输出完成，已保存")
                }
            } else {
                // 非流式输出
                let result = try await AIService.shared.optimize(
                    userPrompt: originalContent,
                    config: config
                )
                
                // 检查是否被取消
                guard !isCancelled else {
                    AILogger.shared.log("非流式输出已被取消")
                    return
                }
                
                text = result
                sessionStore.updateVersionContent(version.id, content: result)
                sessionStore.save()
                AILogger.shared.log("非流式输出完成，已保存")
            }
        } catch is CancellationError {
            // 任务被取消，不显示错误
            AILogger.shared.log("优化任务被取消")
            // 如果版本内容为空，删除它
            if sessionStore.session.versions.first(where: { $0.id == version.id })?.content.isEmpty ?? true {
                sessionStore.session.versions.removeAll { $0.id == version.id }
                sessionStore.session.selectedVersionId = nil
                text = sessionStore.session.originalContent
            }
            sessionStore.save()
        } catch let error as AIServiceError {
            guard !isCancelled else { return }
            errorMessage = error.localizedDescription
            showErrorAlert = true
            AILogger.shared.log("AI服务错误: \(error.localizedDescription)")
            // 删除刚创建的空版本
            sessionStore.session.versions.removeAll { $0.id == version.id }
            sessionStore.session.selectedVersionId = nil
            sessionStore.save()
            text = sessionStore.session.originalContent
        } catch {
            guard !isCancelled else { return }
            errorMessage = error.localizedDescription
            showErrorAlert = true
            AILogger.shared.log("未知错误: \(error.localizedDescription)")
            // 删除刚创建的空版本
            sessionStore.session.versions.removeAll { $0.id == version.id }
            sessionStore.session.selectedVersionId = nil
            sessionStore.save()
            text = sessionStore.session.originalContent
        }
        
        isOptimizing = false
        currentStreamingVersionId = nil
        optimizeTask = nil
    }
    
    // MARK: - 复制操作
    
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
    
    // MARK: - 拖拽处理
    
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
