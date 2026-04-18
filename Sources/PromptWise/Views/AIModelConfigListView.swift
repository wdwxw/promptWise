import SwiftUI

struct AIModelConfigListView: View {
    @EnvironmentObject var theme: ThemeManager
    @StateObject private var store = AIModelConfigStore.shared
    @State private var editingConfig: AIModelConfig?
    @State private var showingNewConfig = false
    @Environment(\.dismiss) private var dismiss
    
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
                
                Text("模型配置")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                
                Spacer()
                
                // 添加按钮
                Button {
                    showingNewConfig = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("添加配置")
            }
            .padding(16)
            
            Divider().background(theme.border)
            
            // 配置列表
            if store.configs.isEmpty {
                emptyState
            } else {
                configList
            }
            
            Divider().background(theme.border)
            
            // 底部按钮
            HStack {
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding(16)
        }
        .frame(width: 400, height: 480)
        .background(theme.panelBg)
        .sheet(item: $editingConfig) { config in
            AIModelConfigEditorView(config: config, isNew: false)
                .environmentObject(theme)
                .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
        }
        .sheet(isPresented: $showingNewConfig) {
            AIModelConfigEditorView(config: AIModelConfig(), isNew: true)
                .environmentObject(theme)
                .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
        }
        .environment(\.colorScheme, theme.mode == .dark ? .dark : .light)
    }
    
    // MARK: - 空状态
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("暂无模型配置")
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
            Button("添加配置") {
                showingNewConfig = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 配置列表
    
    private var configList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.configs) { config in
                    configRow(config)
                }
            }
        }
    }
    
    @State private var hoveredConfigId: UUID?
    
    private func configRow(_ config: AIModelConfig) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(config.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        
                        // 编辑按钮 - 始终显示
                        Button {
                            editingConfig = config
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundStyle(
                                    hoveredConfigId == config.id
                                        ? theme.accent
                                        : theme.textTertiary
                                )
                        }
                        .buttonStyle(.plain)
                        .help("编辑配置")
                    }
                    
                    HStack(spacing: 8) {
                        Text(config.apiFormat.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.surfaceBg)
                            .clipShape(Capsule())
                        Text(config.modelName)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if store.selectedConfigId == config.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                store.selectedConfigId == config.id
                    ? theme.accent.opacity(0.1)
                    : hoveredConfigId == config.id
                        ? theme.surfaceBg.opacity(0.5)
                        : Color.clear
            )
            .contentShape(Rectangle())
            .onHover { isHovered in
                hoveredConfigId = isHovered ? config.id : nil
            }
            .onTapGesture {
                store.selectConfig(id: config.id)
            }
            .contextMenu {
                Button {
                    editingConfig = config
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    store.deleteConfig(id: config.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            
            Divider()
                .background(theme.border)
                .padding(.leading, 16)
        }
    }
}
