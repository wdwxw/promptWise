import SwiftUI

struct AIModelConfigEditorView: View {
    @EnvironmentObject var theme: ThemeManager
    @StateObject private var store = AIModelConfigStore.shared
    @Environment(\.dismiss) private var dismiss
    
    let isNew: Bool
    
    @State private var config: AIModelConfig
    @State private var ollamaModels: [String] = []
    @State private var isFetchingModels = false
    @State private var fetchError: String?
    @State private var useCustomModelName = false  // Ollama 是否使用自定义输入
    
    init(config: AIModelConfig, isNew: Bool) {
        self.isNew = isNew
        _config = State(initialValue: config)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                // 关闭按钮
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("关闭")
                
                Spacer()
                
                // 标题：新建时显示"新建配置"，编辑时显示配置名称
                VStack(spacing: 2) {
                    Text(isNew ? "新建配置" : config.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    if !isNew {
                        Text("编辑配置")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                
                Spacer()
                
                // 占位符保持居中
                Color.clear
                    .frame(width: 20, height: 20)
            }
            .padding(16)
            
            Divider().background(theme.border)
            
            // 表单
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 基本信息
                    formSection("基本信息") {
                        formField("名称") {
                            TextField("配置名称", text: $config.name)
                                .textFieldStyle(.plain)
                                .foregroundStyle(theme.textPrimary)
                                .padding(8)
                                .background(theme.surfaceBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        formField("API 格式") {
                            Picker("", selection: $config.apiFormat) {
                                ForEach(APIFormat.allCases) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: config.apiFormat) { newFormat in
                                config.baseURL = newFormat.defaultBaseURL
                                ollamaModels = []
                                useCustomModelName = false
                            }
                        }
                    }
                    
                    // 连接设置
                    formSection("连接设置") {
                        formField("Base URL") {
                            TextField("https://api.example.com", text: $config.baseURL)
                                .textFieldStyle(.plain)
                                .foregroundStyle(theme.textPrimary)
                                .padding(8)
                                .background(theme.surfaceBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        if config.apiFormat.requiresAPIKey {
                            formField("API Key") {
                                SecureField("sk-...", text: $config.apiKey)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(theme.textPrimary)
                                    .padding(8)
                                    .background(theme.surfaceBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                            }
                        }
                        
                        // 模型名称
                        formField("模型名称") {
                            if config.apiFormat == .ollama {
                                // Ollama: 下拉选择 + 自定义输入切换
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        if !useCustomModelName && !ollamaModels.isEmpty {
                                            Menu {
                                                ForEach(ollamaModels, id: \.self) { model in
                                                    Button {
                                                        config.modelName = model
                                                    } label: {
                                                        HStack {
                                                            Text(model)
                                                            if config.modelName == model {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                HStack {
                                                    Text(config.modelName.isEmpty ? "选择模型" : config.modelName)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(theme.textPrimary)
                                                    Spacer()
                                                    Image(systemName: "chevron.up.chevron.down")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(theme.textSecondary)
                                                }
                                                .padding(8)
                                                .background(theme.surfaceBg)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(theme.border, lineWidth: 1)
                                                )
                                            }
                                            .menuStyle(.borderlessButton)
                                            .frame(maxWidth: .infinity)
                                        } else {
                                            TextField("llama3", text: $config.modelName)
                                                .textFieldStyle(.plain)
                                                .foregroundStyle(theme.textPrimary)
                                                .padding(8)
                                                .background(theme.surfaceBg)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(theme.border, lineWidth: 1)
                                                )
                                        }
                                        
                                        Button {
                                            Task { await fetchOllamaModels() }
                                        } label: {
                                            if isFetchingModels {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                    .frame(width: 14, height: 14)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                                    .foregroundStyle(theme.textSecondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .padding(8)
                                        .background(theme.surfaceBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(theme.border, lineWidth: 1)
                                        )
                                        .disabled(isFetchingModels)
                                        .help("获取模型列表")
                                    }
                                    
                                    if !ollamaModels.isEmpty {
                                        Toggle("手动输入模型名称", isOn: $useCustomModelName)
                                            .toggleStyle(.switch)
                                            .controlSize(.small)
                                            .tint(theme.accent)
                                    }
                                }
                            } else {
                                // OpenAI: 直接文本输入
                                TextField("gpt-4o", text: $config.modelName)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(theme.textPrimary)
                                    .padding(8)
                                    .background(theme.surfaceBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                            }
                        }
                        
                        if let error = fetchError {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                        }
                    }
                    
                    // 系统提示语
                    formSection("系统提示语") {
                        TextEditor(text: $config.systemPrompt)
                            .frame(height: 100)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(theme.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.border, lineWidth: 1)
                            )
                    }
                    
                    // 参数设置
                    formSection("参数设置") {
                        formField("温度 (\(String(format: "%.1f", config.temperature)))") {
                            Slider(value: $config.temperature, in: 0...2, step: 0.1)
                                .tint(theme.accent)
                        }
                        
                        formField("Token 上限") {
                            TextField("2048", value: $config.maxTokens, format: .number)
                                .textFieldStyle(.plain)
                                .foregroundStyle(theme.textPrimary)
                                .padding(8)
                                .background(theme.surfaceBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        HStack {
                            Text("启用流式输出")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Toggle("", isOn: $config.streamEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        
                        // 思考模式开关（仅 Ollama）
                        if config.apiFormat == .ollama {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("启用思考模式")
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.textPrimary)
                                    Spacer()
                                    Toggle("", isOn: $config.thinkEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                Text("支持 Qwen3、DeepSeek R1、Gemma 4 等模型。关闭后响应更快但不显示推理过程。")
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }
                .padding(16)
            }
            
            Divider().background(theme.border)
            
            // 底部按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button(isNew ? "添加" : "保存") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(theme.accent)
                .disabled(config.name.isEmpty || config.modelName.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 420, height: 580)
        .background(theme.panelBg)
        .onAppear {
            if config.apiFormat == .ollama && !config.baseURL.isEmpty {
                Task { await fetchOllamaModels() }
            }
        }
        .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
    }
    
    // MARK: - 表单组件
    
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }
    
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
            content()
        }
    }
    
    // MARK: - 操作方法
    
    private func fetchOllamaModels() async {
        isFetchingModels = true
        fetchError = nil
        
        do {
            ollamaModels = try await AIService.shared.fetchOllamaModels(baseURL: config.baseURL)
            if !ollamaModels.isEmpty && config.modelName.isEmpty {
                config.modelName = ollamaModels.first ?? ""
            }
            // 如果当前模型名不在列表中，切换到自定义输入模式
            if !ollamaModels.isEmpty && !ollamaModels.contains(config.modelName) && !config.modelName.isEmpty {
                useCustomModelName = true
            }
        } catch {
            fetchError = error.localizedDescription
        }
        
        isFetchingModels = false
    }
    
    private func saveConfig() {
        if isNew {
            store.addConfig(config)
        } else {
            store.updateConfig(config)
        }
        dismiss()
    }
}
