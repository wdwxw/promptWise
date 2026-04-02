import SwiftUI
import Charts

struct PromptStatsView: View {
    @ObservedObject var store: PromptStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingClearAllAlert = false
    @State private var showingClearRecentAlert = false

    private var sortedPrompts: [Prompt] {
        store.prompts.sorted { $0.usageCount > $1.usageCount }
    }

    private var totalUsage: Int {
        store.prompts.reduce(0) { $0 + $1.usageCount }
    }

    private var recentTotalUsage: Int {
        store.prompts.reduce(0) { $0 + recentCount($1) }
    }

    private func recentCount(_ prompt: Prompt) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return prompt.recentUsages.filter { $0 >= cutoff }.count
    }

    private var chartData: [Prompt] {
        Array(sortedPrompts.filter { $0.usageCount > 0 }.prefix(10))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summarySection
                    if !chartData.isEmpty {
                        chartSection
                    }
                    tableSection
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 620)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Label("提示语使用统计", systemImage: "chart.bar.xaxis")
                .font(.headline)
            Spacer()
            Button {
                showingClearRecentAlert = true
            } label: {
                Text("清除 7 天")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .alert("清除近 7 天记录", isPresented: $showingClearRecentAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) { store.clearRecentUsageStats() }
            } message: {
                Text("将清除所有提示语的近 7 天使用记录，累计总次数不变。")
            }

            Button {
                showingClearAllAlert = true
            } label: {
                Text("清除全部统计")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .alert("清除全部统计", isPresented: $showingClearAllAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) { store.clearAllUsageStats() }
            } message: {
                Text("将清除所有提示语的累计次数和近 7 天记录，此操作不可撤销。")
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Summary Cards

    private var summarySection: some View {
        HStack(spacing: 12) {
            statCard(
                title: "提示语总数",
                value: "\(store.prompts.count)",
                icon: "doc.text",
                color: .blue
            )
            statCard(
                title: "累计使用次数",
                value: "\(totalUsage)",
                icon: "hand.tap",
                color: .purple
            )
            statCard(
                title: "近 7 天使用",
                value: "\(recentTotalUsage)",
                icon: "clock.arrow.circlepath",
                color: .green
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("使用次数 Top \(chartData.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(chartData) { prompt in
                BarMark(
                    x: .value("次数", prompt.usageCount),
                    y: .value("提示语", shortTitle(prompt.title))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.7), Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text("\(prompt.usageCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .frame(height: CGFloat(chartData.count * 32 + 20))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Table

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("全部提示语")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                tableHeaderRow
                Divider()
                ForEach(Array(sortedPrompts.enumerated()), id: \.element.id) { index, prompt in
                    tableRow(prompt: prompt, index: index)
                    if index < sortedPrompts.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var tableHeaderRow: some View {
        HStack {
            Text("提示语标题")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("累计")
                .frame(width: 50, alignment: .trailing)
            Text("近 7 天")
                .frame(width: 56, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
    }

    private func tableRow(prompt: Prompt, index: Int) -> some View {
        let recent = recentCount(prompt)
        return HStack {
            HStack(spacing: 6) {
                if prompt.usageCount > 0 {
                    Text("#\(index + 1)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .trailing)
                } else {
                    Text("—")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, alignment: .trailing)
                }
                Text(prompt.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(prompt.usageCount > 0 ? "\(prompt.usageCount)" : "—")
                .font(.system(size: 12, weight: prompt.usageCount > 0 ? .semibold : .regular))
                .foregroundStyle(prompt.usageCount > 0 ? Color.primary : Color.secondary.opacity(0.5))
                .frame(width: 50, alignment: .trailing)

            Text(recent > 0 ? "\(recent)" : "—")
                .font(.system(size: 12, weight: recent > 0 ? .semibold : .regular))
                .foregroundStyle(recent > 0 ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.018))
    }

    // MARK: - Helpers

    private func shortTitle(_ title: String) -> String {
        title.count > 16 ? String(title.prefix(14)) + "…" : title
    }
}
