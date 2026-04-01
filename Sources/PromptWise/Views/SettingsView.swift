import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                Text("主题：")
                    .font(.system(size: 13))
                    .frame(width: 70, alignment: .trailing)

                Picker("", selection: $theme.mode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Divider()

            HStack(spacing: 12) {
                Text("快捷图标：")
                    .font(.system(size: 13))
                    .frame(width: 70, alignment: .trailing)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("悬停展开最近提示语", isOn: $theme.quickAccessEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    if theme.quickAccessEnabled {
                        HStack(spacing: 6) {
                            Text("显示条数")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Picker("", selection: $theme.quickAccessItemCount) {
                                ForEach(ThemeManager.itemCountOptions, id: \.self) { count in
                                    Text("\(count) 条").tag(count)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 70)
                            .controlSize(.small)
                        }

                        HStack(spacing: 6) {
                            Text("自动收起")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Picker("", selection: $theme.quickAccessDismissDelay) {
                                ForEach(ThemeManager.dismissDelayOptions, id: \.self) { sec in
                                    Text("\(Int(sec)) 秒").tag(sec)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 70)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(30)
        .frame(width: 340)
    }
}
