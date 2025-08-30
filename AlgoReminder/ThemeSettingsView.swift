import SwiftUI

// MARK: - 主题设置视图
struct ThemeSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    let themeModes: [AppSettings.ThemeMode] = [.light, .dark, .system]
    let cardStyles: [AppSettings.CardStyle] = [.modern, .classic, .compact]
    let accentColors: [Color] = [.blue, .green, .purple, .orange, .red, .pink, .mint, .indigo]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 主题模式
            VStack(alignment: .leading, spacing: 8) {
                Text("主题模式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(themeModes, id: \.rawValue) { mode in
                        Button(action: {
                            settings.themeMode = mode
                            settings.saveSettings()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: modeIconName(mode))
                                    .font(.system(size: 24))
                                    .foregroundColor(settings.themeMode == mode ? settings.accentColor : .secondary)
                                
                                Text(mode.displayName)
                                    .font(.caption)
                                    .foregroundColor(settings.themeMode == mode ? settings.accentColor : .secondary)
                            }
                            .frame(width: 80, height: 60)
                            .background(settings.themeMode == mode ? settings.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 强调色
            VStack(alignment: .leading, spacing: 8) {
                Text("强调色")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(accentColors, id: \.self) { color in
                        Button(action: {
                            settings.accentColor = color
                            settings.saveSettings()
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: settings.accentColor == color ? 2 : 0)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 卡片样式
            VStack(alignment: .leading, spacing: 8) {
                Text("卡片样式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(cardStyles, id: \.rawValue) { style in
                        Button(action: {
                            settings.cardStyle = style
                            settings.saveSettings()
                        }) {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(settings.cardStyle == style ? settings.accentColor.opacity(0.3) : Color.secondary.opacity(0.3))
                                    .frame(width: 40, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(settings.cardStyle == style ? settings.accentColor : Color.clear, lineWidth: 2)
                                    )
                                
                                Text(style.displayName)
                                    .font(.caption)
                                    .foregroundColor(settings.cardStyle == style ? settings.accentColor : .secondary)
                            }
                            .frame(width: 70, height: 50)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 预览
            VStack(alignment: .leading, spacing: 8) {
                Text("预览")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("示例卡片")
                            .font(.headline)
                        
                        Text("这是一个示例卡片，展示当前主题效果")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("标签1")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(settings.accentColor.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text("标签2")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(settings.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(settings.accentColor, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func modeIconName(_ mode: AppSettings.ThemeMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gearshape.fill"
        }
    }
}