import SwiftUI

struct AIModelConfigListView: View {
    @EnvironmentObject var theme: ThemeManager
    @StateObject private var store = AIModelConfigStore.shared
    @State private var editingConfig: AIModelConfig?
    @State private var showingNewConfig = false
    @Environment(\.dismiss) private var dismiss
    
    private var subtleSurface: Color {
        theme.mode == .dark ? theme.surfaceBg.opacity(0.55) : theme.surfaceBg.opacity(0.75)
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
                        .frame(width: 28, height: 28)
                        .background(subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("关闭")
                
                Spacer()
                
                Text("模型配置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                
                Spacer()
                
                // 添加按钮
                Button {
                    showingNewConfig = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("添加配置")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            Divider().background(theme.border)
            
            // 配置列表
            if store.configs.isEmpty {
                emptyState
            } else {
                configList
            }
            
            Divider().background(theme.border)
            
            // 底部按钮
            HStack(spacing: 12) {
                Spacer()
                footerButton("完成", primary: true) {
                    dismiss()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(subtleSurface.opacity(0.45))
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
    
    private func footerButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(primary ? Color.white : theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(primary ? theme.accent : theme.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(primary ? Color.clear : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 空状态
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 36))
                .foregroundStyle(theme.textTertiary)
            Text("暂无模型配置")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text("点击右上角 + 快速创建一个模型配置")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        store.selectedConfigId == config.id
                            ? theme.accent.opacity(0.12)
                            : hoveredConfigId == config.id
                                ? subtleSurface
                                : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        store.selectedConfigId == config.id ? theme.accent.opacity(0.35) : theme.border.opacity(0),
                        lineWidth: 1
                    )
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
                .padding(.trailing, 6)
        }
    }
}
