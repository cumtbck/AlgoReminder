import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var settings = AppSettings.shared
    @State private var showingResetAlert = false
    let onDismiss: () -> Void
    
    // 添加默认初始化方法
    init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具条（自定义，避免 NavigationView 产生分栏）
            HStack {
                Text("设置").font(.title3.bold())
                Spacer()
                Button("取消") {
                    settings.loadSettings()
                    onDismiss()
                }
                Button("保存") {
                    settings.saveSettings()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    GroupBox(label: Label("菜单栏图标", systemImage: "menubar.rectangle").font(.headline)) {
                        MenuBarIconSettingsView()
                    }
                    GroupBox(label: Label("功能图标", systemImage: "square.grid.2x2.fill").font(.headline)) {
                        FeatureIconSettingsView()
                    }
                    GroupBox(label: Label("应用设置", systemImage: "slider.horizontal.3").font(.headline)) {
                        AppGeneralSettingsView()
                    }
                    GroupBox(label: Label("主题设置", systemImage: "paintpalette.fill").font(.headline)) {
                        ThemeSettingsView()
                    }
                    GroupBox(label: Label("管理", systemImage: "wrench.and.screwdriver.fill").font(.headline)) {
                        Button(role: .destructive) {
                            showingResetAlert = true
                        } label: {
                            Label("重置所有设置", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 640, minHeight: 520)
        .alert("重置设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                settings.resetToDefaults()
                onDismiss()
            }
        } message: {
            Text("确定要将所有设置恢复为默认值吗？此操作无法撤销。")
        }
    }
}

// MARK: - 菜单栏图标设置视图
struct MenuBarIconSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    let availableIcons = [
        "brain.head.profile",
        "book.fill",
        "graduationcap.fill",
        "lightbulb.fill",
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "leaf.fill",
        "flame.fill",
        "sparkles"
    ]
    
    let availableColors: [Color] = [
        .primary, .blue, .green, .orange, .red, .purple, .pink, .mint
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图标选择
            VStack(alignment: .leading, spacing: 8) {
                Text("图标样式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 50, maximum: 60))
                ], spacing: 8) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Button(action: {
                            settings.menuBarIconName = iconName
                            // 实时保存设置
                            settings.saveSettings()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(settings.menuBarIconName == iconName ? settings.menuBarIconColor : .secondary)
                                
                                if settings.menuBarIconName == iconName {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                }
                            }
                            .frame(width: 50, height: 50)
                            .background(settings.menuBarIconName == iconName ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 图标颜色
            VStack(alignment: .leading, spacing: 8) {
                Text("图标颜色")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(availableColors, id: \.self) { color in
                        Button(action: {
                            settings.menuBarIconColor = color
                            // 实时保存设置
                            settings.saveSettings()
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: settings.menuBarIconColor == color ? 2 : 0)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // 徽章设置
            Toggle("显示任务数量徽章", isOn: Binding(
                get: { settings.showMenuBarBadge },
                set: { 
                    settings.showMenuBarBadge = $0
                    settings.saveSettings()
                }
            ))
            
            if settings.showMenuBarBadge {
                VStack(alignment: .leading, spacing: 8) {
                    Text("徽章颜色")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach([Color.red, .orange, .blue, .green, .purple], id: \.self) { color in
                            Button(action: {
                                settings.badgeColor = color
                                // 实时保存设置
                                settings.saveSettings()
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 25, height: 25)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: settings.badgeColor == color ? 2 : 0)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // 预览
            VStack(alignment: .leading, spacing: 8) {
                Text("预览")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: settings.menuBarIconName)
                        .font(.system(size: 16))
                        .foregroundColor(settings.menuBarIconColor)
                    
                    if settings.showMenuBarBadge {
                        Text("3")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(settings.badgeColor)
                            .clipShape(Circle())
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 功能图标设置视图
struct FeatureIconSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    let featureIcons = [
        ("problemIconName", "题目", "doc.text", ["doc.text", "book.fill", "folder.fill", "doc.fill", "list.bullet"]),
        ("reviewIconName", "复习", "clock.arrow.circlepath", ["clock.arrow.circlepath", "clock.fill", "timer", "hourglass", "calendar"]),
        ("noteIconName", "笔记", "note.text", ["note.text", "doc.richtext", "pencil.and.outline", "highlighter", "square.and.pencil"]),
        ("settingsIconName", "设置", "gearshape", ["gearshape", "gear", "slider.horizontal.3", "switch.2", "wrench.and.screwdriver"])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(featureIcons, id: \.0) { (key, title, defaultIcon, alternatives) in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(title)图标")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(alternatives, id: \.self) { iconName in
                            Button(action: {
                                switch key {
                                case "problemIconName":
                                    settings.problemIconName = iconName
                                case "reviewIconName":
                                    settings.reviewIconName = iconName
                                case "noteIconName":
                                    settings.noteIconName = iconName
                                case "settingsIconName":
                                    settings.settingsIconName = iconName
                                default:
                                    break
                                }
                                // 实时保存设置
                                settings.saveSettings()
                            }) {
                                Image(systemName: iconName)
                                    .font(.system(size: 20))
                                    .foregroundColor(isSelected(key: key, iconName: iconName) ? .accentColor : .secondary)
                                    .frame(width: 40, height: 40)
                                    .background(isSelected(key: key, iconName: iconName) ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func isSelected(key: String, iconName: String) -> Bool {
        switch key {
        case "problemIconName":
            return settings.problemIconName == iconName
        case "reviewIconName":
            return settings.reviewIconName == iconName
        case "noteIconName":
            return settings.noteIconName == iconName
        case "settingsIconName":
            return settings.settingsIconName == iconName
        default:
            return false
        }
    }
}

// MARK: - 应用通用设置视图
struct AppGeneralSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("显示动画效果", isOn: Binding(
                get: { settings.showAnimations },
                set: { 
                    settings.showAnimations = $0
                    settings.saveSettings()
                }
            ))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("版本信息")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("素晴らしき日々～不連続存在～")
                        .font(.caption)
                    Spacer()
                    Text("7.2.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}